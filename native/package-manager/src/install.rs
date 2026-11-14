// install.rs — Installation engine: yay subprocess, streaming output, security

use crate::package::{Package, Source};
use std::ffi::OsString;
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::process::Command;
use tokio::sync::mpsc;

#[derive(Debug, Clone)]
pub enum InstallEvent {
    Line(String),
    Progress(u8), // 0–100
    Done(bool),   // success
}

/// Safety guard: prevents concurrent yay operations
pub struct OpGuard(Arc<AtomicBool>);

impl OpGuard {
    /// Returns None if an operation is already running
    pub fn acquire(flag: &Arc<AtomicBool>) -> Option<OpGuard> {
        if flag
            .compare_exchange(false, true, Ordering::Acquire, Ordering::Relaxed)
            .is_ok()
        {
            Some(OpGuard(flag.clone()))
        } else {
            None
        }
    }
}

impl Drop for OpGuard {
    fn drop(&mut self) {
        self.0.store(false, Ordering::Release);
    }
}

/// Builds the yay install argv — no shell interpolation, never as root
fn install_argv(pkg: &Package) -> Vec<OsString> {
    let mut args: Vec<OsString> = vec![
        "yay".into(),
        "-S".into(),
        "--needed".into(),
    ];
    // For AUR packages, explicitly target the AUR to avoid shadowing
    match &pkg.source {
        Source::Aur => args.push("--aur".into()),
        Source::Official(repo) => {
            // e.g. "--repo" flag not needed for official; yay handles it
            let _ = repo;
        }
    }
    args.push("--".into());
    args.push((&pkg.name).into());
    args
}

/// Builds the yay remove argv
fn remove_argv(pkg: &Package) -> Vec<OsString> {
    vec![
        "yay".into(),
        "-Rns".into(),
        "--".into(),
        (&pkg.name).into(),
    ]
}

/// Spawn a yay install/remove operation; stream events back via channel
/// Returns a JoinHandle for optional SIGTERM
pub async fn run_install(
    pkg: Package,
    remove: bool,
    tx: mpsc::Sender<InstallEvent>,
    busy: Arc<AtomicBool>,
) {
    // Safety: never run as root
    let euid = unsafe { libc::geteuid() };
    if euid == 0 {
        let _ = tx
            .send(InstallEvent::Line(
                "ERROR: refusing to run yay as root".into(),
            ))
            .await;
        let _ = tx.send(InstallEvent::Done(false)).await;
        return;
    }

    let _guard = match OpGuard::acquire(&busy) {
        Some(g) => g,
        None => {
            let _ = tx
                .send(InstallEvent::Line(
                    "Another package operation is already running.".into(),
                ))
                .await;
            let _ = tx.send(InstallEvent::Done(false)).await;
            return;
        }
    };

    let argv = if remove {
        remove_argv(&pkg)
    } else {
        install_argv(&pkg)
    };

    // argv[0] is "yay"; the rest are args
    let mut cmd = Command::new("yay");
    cmd.args(&argv[1..]);
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => {
            let _ = tx
                .send(InstallEvent::Line(format!("Failed to spawn yay: {e}")))
                .await;
            let _ = tx.send(InstallEvent::Done(false)).await;
            return;
        }
    };

    let stdout = child.stdout.take().expect("stdout piped");
    let stderr = child.stderr.take().expect("stderr piped");
    let tx2 = tx.clone();

    // Stream stdout
    let tx_out = tx.clone();
    tokio::spawn(async move {
        let mut reader = BufReader::new(stdout).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            // Parse progress: yay prints "( 1/5) Installing neovim..."
            let progress = parse_progress(&line);
            if let Some(pct) = progress {
                let _ = tx_out.send(InstallEvent::Progress(pct)).await;
            }
            let _ = tx_out.send(InstallEvent::Line(line)).await;
        }
    });

    // Stream stderr
    tokio::spawn(async move {
        let mut reader = BufReader::new(stderr).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let _ = tx2.send(InstallEvent::Line(format!("! {line}"))).await;
        }
    });

    let status = child.wait().await;
    let success = status.map(|s| s.success()).unwrap_or(false);
    let _ = tx.send(InstallEvent::Done(success)).await;
}

fn parse_progress(line: &str) -> Option<u8> {
    // Pattern: "( 2/7)" at start of line
    let trimmed = line.trim();
    if !trimmed.starts_with('(') {
        return None;
    }
    let end = trimmed.find(')')?;
    let inner = &trimmed[1..end];
    let mut parts = inner.splitn(2, '/');
    let cur: u64 = parts.next()?.trim().parse().ok()?;
    let total: u64 = parts.next()?.trim().parse().ok()?;
    if total == 0 {
        return None;
    }
    Some(((cur * 100) / total) as u8)
}
