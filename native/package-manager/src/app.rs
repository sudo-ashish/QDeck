// app.rs — Top-level App state machine + event loop

use crate::config::Config;
use crate::install::{self, InstallEvent};
use crate::package::Package;
use crate::search;
use crate::ui;

use std::collections::HashMap;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use std::time::{Duration, Instant};

use crossterm::event::{
    self, Event, KeyCode, KeyEvent, KeyModifiers,
};
use ratatui::{backend::CrosstermBackend, Terminal};
use tokio::sync::mpsc;

use std::io::Stdout;

// ── Panels ─────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FocusedPanel {
    Search,
    Results,
    Details,
}

// ── App state ──────────────────────────────────────────────────────────────

#[derive(Debug)]
pub enum AppState {
    /// Normal browsing
    Browsing,
    /// An install/remove operation is running
    Installing {
        package:   Package,
        removing:  bool,
        log_lines: Vec<String>,
        progress:  u8,
    },
    /// Just finished an operation
    Done { success: bool, message: String },
}

// ── App ────────────────────────────────────────────────────────────────────

pub struct App {
    pub config:         Config,
    pub state:          AppState,
    pub focused:        FocusedPanel,
    pub search_query:   String,
    pub results:        Vec<Package>,
    pub selected_index: usize,
    pub searching:      bool,
    pub aur_error:      Option<String>,

    /// Cached installed packages from `pacman -Q`
    installed_cache:    HashMap<String, String>,

    /// Whether a package op is running
    busy:               Arc<AtomicBool>,

    /// Debounce: when the user last typed
    last_keypress:      Option<Instant>,

    /// Channel for receiving search results
    search_tx:          mpsc::Sender<SearchResult>,
    search_rx:          mpsc::Receiver<SearchResult>,

    /// Channel for receiving install events
    install_tx:         mpsc::Sender<InstallEvent>,
    install_rx:         mpsc::Receiver<InstallEvent>,

    /// Default package manager modal
    pub show_default_mgr_modal: bool,
    pub default_mgr_options:    Vec<(String, String)>,
    pub default_mgr_selected:   usize,
    pub current_default_mgr:    String,
    pub status_notification:    Option<(String, Instant)>,
}

struct SearchResult {
    query:     String,
    packages:  Vec<Package>,
    aur_error: Option<String>,
}

impl App {
    pub fn new(initial_query: Option<String>) -> Self {
        let (search_tx, search_rx) = mpsc::channel(32);
        let (install_tx, install_rx) = mpsc::channel(256);

        Self {
            config:         Config::load(),
            state:          AppState::Browsing,
            focused:        FocusedPanel::Search,
            search_query:   initial_query.unwrap_or_default(),
            results:        vec![],
            selected_index: 0,
            searching:      false,
            aur_error:      None,
            installed_cache: HashMap::new(),
            busy:           Arc::new(AtomicBool::new(false)),
            last_keypress:  None,
            search_tx,
            search_rx,
            install_tx,
            install_rx,
            show_default_mgr_modal: false,
            default_mgr_options:    vec![],
            default_mgr_selected:   0,
            current_default_mgr:    crate::config::get_default_pkg_mgr(),
            status_notification:    None,
        }
    }

    /// Return the currently highlighted package (if any)
    pub fn selected_package(&self) -> Option<&Package> {
        self.results.get(self.selected_index)
    }

    // ── Event loop ─────────────────────────────────────────────────────────

    pub async fn run(
        &mut self,
        terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    ) -> anyhow::Result<()> {
        // Initial installed cache
        self.installed_cache = search::installed_packages().await;

        // If initial query given, start searching immediately
        if !self.search_query.is_empty() {
            self.trigger_search();
        }

        loop {
            // Draw frame
            terminal.draw(|f| ui::draw(f, self))?;

            // Handle Done state auto-dismiss
            if let AppState::Done { .. } = &self.state {
                tokio::time::sleep(Duration::from_secs(2)).await;
                self.state = AppState::Browsing;
                // Refresh installed cache after operation
                self.installed_cache = search::installed_packages().await;
                if !self.search_query.is_empty() {
                    self.trigger_search();
                }
                continue;
            }

            // Poll for events with 50ms timeout (20 fps)
            let timeout = Duration::from_millis(50);
            if event::poll(timeout)? {
                if let Event::Key(key) = event::read()? {
                    if self.handle_key(key).await? {
                        break; // quit
                    }
                }
            }

            // Check for debounced search trigger
            self.check_debounce().await;

            // Drain search results channel
            self.drain_search_results();

            // Drain install events channel
            self.drain_install_events();
        }

        Ok(())
    }

    // ── Keyboard handler ───────────────────────────────────────────────────

    /// Returns true if the app should quit
    async fn handle_key(&mut self, key: KeyEvent) -> anyhow::Result<bool> {
        // Global: Ctrl-C always quits (or cancels install)
        if key.modifiers == KeyModifiers::CONTROL && key.code == KeyCode::Char('c') {
            if matches!(self.state, AppState::Installing { .. }) {
                // Cancel: drop the receiver to unblock the sender
                // The install task will get a send error and stop
                return Ok(false); // just dismiss next tick
            }
            return Ok(true);
        }

        // If installing, only allow Ctrl-C
        if matches!(self.state, AppState::Installing { .. }) {
            return Ok(false);
        }

        if self.show_default_mgr_modal {
            return self.handle_key_default_mgr_modal(key).await;
        }

        match self.focused {
            FocusedPanel::Search => self.handle_key_search(key).await,
            FocusedPanel::Results => self.handle_key_results(key).await,
            FocusedPanel::Details => self.handle_key_details(key).await,
        }
    }

    async fn handle_key_search(&mut self, key: KeyEvent) -> anyhow::Result<bool> {
        match key.code {
            KeyCode::Esc => {
                if !self.search_query.is_empty() {
                    self.search_query.clear();
                    self.results.clear();
                    self.selected_index = 0;
                } else {
                    self.focused = FocusedPanel::Results;
                }
            }
            KeyCode::Char(c) => {
                self.search_query.push(c);
                self.last_keypress = Some(Instant::now());
            }
            KeyCode::Backspace => {
                self.search_query.pop();
                self.last_keypress = Some(Instant::now());
            }
            KeyCode::Enter | KeyCode::Down => {
                if !self.results.is_empty() {
                    self.focused = FocusedPanel::Results;
                }
            }
            KeyCode::Tab => {
                self.focused = FocusedPanel::Results;
            }
            _ => {}
        }
        Ok(false)
    }

    async fn handle_key_results(&mut self, key: KeyEvent) -> anyhow::Result<bool> {
        match key.code {
            KeyCode::Char('q') => return Ok(true),
            KeyCode::Char('/') => {
                self.focused = FocusedPanel::Search;
            }
            KeyCode::Char('r') => {
                if !self.search_query.is_empty() {
                    self.trigger_search();
                }
            }
            KeyCode::Up | KeyCode::Char('k') => {
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.selected_index + 1 < self.results.len() {
                    self.selected_index += 1;
                }
            }
            KeyCode::PageUp => {
                self.selected_index = self.selected_index.saturating_sub(10);
            }
            KeyCode::PageDown => {
                let max = self.results.len().saturating_sub(1);
                self.selected_index = (self.selected_index + 10).min(max);
            }
            KeyCode::Enter | KeyCode::Tab => {
                self.focused = FocusedPanel::Details;
            }
            KeyCode::Char('i') => {
                self.start_install(false).await;
            }
            KeyCode::Char('u') => {
                self.start_install(true).await;
            }
            KeyCode::Char('d') => {
                self.open_default_mgr_modal();
            }
            KeyCode::Esc => {
                self.focused = FocusedPanel::Search;
            }
            _ => {}
        }
        Ok(false)
    }

    async fn handle_key_details(&mut self, key: KeyEvent) -> anyhow::Result<bool> {
        match key.code {
            KeyCode::Char('q') => return Ok(true),
            KeyCode::Char('i') => {
                self.start_install(false).await;
            }
            KeyCode::Char('u') => {
                self.start_install(true).await;
            }
            KeyCode::Char('d') => {
                self.open_default_mgr_modal();
            }
            KeyCode::Esc | KeyCode::Tab => {
                self.focused = FocusedPanel::Results;
            }
            KeyCode::Up | KeyCode::Char('k') => {
                self.focused = FocusedPanel::Results;
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.focused = FocusedPanel::Results;
                if self.selected_index + 1 < self.results.len() {
                    self.selected_index += 1;
                }
            }
            _ => {}
        }
        Ok(false)
    }

    pub fn open_default_mgr_modal(&mut self) {
        self.default_mgr_options = crate::config::detect_available_package_managers();
        self.current_default_mgr = crate::config::get_default_pkg_mgr();
        self.default_mgr_selected = self
            .default_mgr_options
            .iter()
            .position(|(b, _)| b == &self.current_default_mgr)
            .unwrap_or(0);
        self.show_default_mgr_modal = true;
    }

    async fn handle_key_default_mgr_modal(&mut self, key: KeyEvent) -> anyhow::Result<bool> {
        match key.code {
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('d') => {
                self.show_default_mgr_modal = false;
            }
            KeyCode::Up | KeyCode::Char('k') => {
                if self.default_mgr_selected > 0 {
                    self.default_mgr_selected -= 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.default_mgr_selected + 1 < self.default_mgr_options.len() {
                    self.default_mgr_selected += 1;
                }
            }
            KeyCode::Enter => {
                if let Some((bin, label)) = self.default_mgr_options.get(self.default_mgr_selected) {
                    let _ = crate::config::set_default_pkg_mgr(bin);
                    self.current_default_mgr = bin.clone();
                    self.status_notification = Some((
                        format!("Default package manager set to: {label}"),
                        Instant::now(),
                    ));
                }
                self.show_default_mgr_modal = false;
            }
            _ => {}
        }
        Ok(false)
    }

    // ── Search ─────────────────────────────────────────────────────────────

    async fn check_debounce(&mut self) {
        if let Some(t) = self.last_keypress {
            let debounce = Duration::from_millis(self.config.search_debounce_ms);
            if t.elapsed() >= debounce {
                self.last_keypress = None;
                if !self.search_query.is_empty() {
                    self.trigger_search();
                } else {
                    self.results.clear();
                    self.selected_index = 0;
                    self.searching = false;
                }
            }
        }
    }

    fn trigger_search(&mut self) {
        let query = self.search_query.clone();
        let tx = self.search_tx.clone();
        let aur_enabled = self.config.aur_enabled;
        let aur_timeout = self.config.aur_timeout_secs;
        let max_results = self.config.max_results;
        let installed = self.installed_cache.clone();

        self.searching = true;

        tokio::spawn(async move {
            // Run pacman and AUR concurrently
            let (official_res, aur_res) = tokio::join!(
                search::search_official(&query),
                async {
                    if aur_enabled {
                        search::search_aur(&query, aur_timeout).await
                    } else {
                        Ok(vec![])
                    }
                }
            );

            let aur_error = match &aur_res {
                Err(e) => Some(e.clone()),
                Ok(_) => None,
            };

            let aur = aur_res.unwrap_or_default();
            let mut merged = search::merge_and_score(&query, official_res, aur, &installed);
            merged.truncate(max_results);

            let _ = tx
                .send(SearchResult {
                    query,
                    packages: merged,
                    aur_error,
                })
                .await;
        });
    }

    fn drain_search_results(&mut self) {
        // Drain all pending results; use the latest one for the current query
        while let Ok(result) = self.search_rx.try_recv() {
            if result.query == self.search_query {
                self.results = result.packages;
                self.aur_error = result.aur_error;
                self.searching = false;
                // Clamp selection
                if self.selected_index >= self.results.len() {
                    self.selected_index = self.results.len().saturating_sub(1);
                }
            }
            // Discard stale results for old queries
        }
    }

    // ── Installation ───────────────────────────────────────────────────────

    async fn start_install(&mut self, remove: bool) {
        if self.busy.load(Ordering::Relaxed) {
            return;
        }

        let Some(pkg) = self.selected_package().cloned() else {
            return;
        };

        // Can't install something not in AUR/official
        if remove && !pkg.installed {
            return;
        }
        if !remove && pkg.installed {
            return; // already installed
        }

        self.state = AppState::Installing {
            package: pkg.clone(),
            removing: remove,
            log_lines: vec![format!(
                "{} {}…",
                if remove { "Removing" } else { "Installing" },
                pkg.name
            )],
            progress: 0,
        };

        let tx = self.install_tx.clone();
        let busy = self.busy.clone();

        tokio::spawn(async move {
            install::run_install(pkg, remove, tx, busy).await;
        });
    }

    fn drain_install_events(&mut self) {
        while let Ok(event) = self.install_rx.try_recv() {
            match event {
                InstallEvent::Line(line) => {
                    if let AppState::Installing { log_lines, .. } = &mut self.state {
                        log_lines.push(line);
                        // Keep at most 500 lines
                        if log_lines.len() > 500 {
                            log_lines.drain(0..100);
                        }
                    }
                }
                InstallEvent::Progress(pct) => {
                    if let AppState::Installing { progress, .. } = &mut self.state {
                        *progress = pct;
                    }
                }
                InstallEvent::Done(success) => {
                    let msg = if success {
                        "Operation completed successfully.".to_string()
                    } else {
                        "Operation failed. Check output above.".to_string()
                    };
                    self.state = AppState::Done { success, message: msg };
                }
            }
        }
    }
}
