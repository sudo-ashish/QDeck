// ui/mod.rs — UI module root; orchestrates all panels

pub mod details;
pub mod layout;
pub mod results;
pub mod search_bar;
pub mod status;

use crate::app::{App, AppState, FocusedPanel};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Clear, Paragraph},
    Frame,
};

/// Main draw entry point called every render tick
pub fn draw(frame: &mut Frame, app: &App) {
    let area = frame.area();

    // Check minimum terminal size
    if area.width < 40 || area.height < 10 {
        let msg = Paragraph::new("Terminal too small.\nPlease resize to at least 40×10.")
            .style(Style::default().fg(Color::Red))
            .block(Block::default().borders(Borders::ALL).title(" QDeck Pkg "));
        frame.render_widget(msg, area);
        return;
    }

    // Outer chrome
    let outer = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::Cyan))
        .title(header_title(app))
        .title_bottom(Line::from(vec![
            Span::styled(" q", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":quit "),
            Span::styled("/", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":search "),
            Span::styled("i", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":install "),
            Span::styled("u", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":remove "),
            Span::styled("d", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":default mgr "),
            Span::styled("Tab", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":switch panel "),
        ]));

    let inner = outer.inner(area);
    frame.render_widget(outer, area);

    let geo = layout::compute(inner, area.width);

    // Always draw search bar
    search_bar::draw(frame, app, geo.search);

    // Draw install progress overlay if installing
    if let AppState::Installing { log_lines, progress, .. } = &app.state {
        draw_install_overlay(frame, app, inner, log_lines, *progress);
        return;
    }

    // Show results + details side by side (or stacked on narrow terminals)
    if geo.has_details {
        results::draw(frame, app, geo.results);
        details::draw(frame, app, geo.details.unwrap());
    } else if app.focused == FocusedPanel::Details {
        // Narrow: details overlay
        details::draw(frame, app, inner);
    } else {
        results::draw(frame, app, geo.results);
    }

    if app.show_default_mgr_modal {
        draw_default_mgr_modal(frame, app, area);
    }
}

fn header_title(app: &App) -> Line<'static> {
    if let Some((msg, time)) = &app.status_notification {
        if time.elapsed().as_secs() < 3 {
            return Line::from(vec![
                Span::styled(
                    " 󰏖 ",
                    Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    format!(" ✓ {msg} "),
                    Style::default().fg(Color::Black).bg(Color::Green).add_modifier(Modifier::BOLD),
                ),
            ]);
        }
    }

    let loading_indicator = if app.searching {
        Span::styled(" ⟳ ", Style::default().fg(Color::Yellow))
    } else {
        Span::raw("   ")
    };

    Line::from(vec![
        Span::styled(
            " 󰏖 QDeck Package Manager ",
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        ),
        loading_indicator,
    ])
}

fn draw_default_mgr_modal(frame: &mut Frame, app: &App, area: Rect) {
    let popup_width = 62.min(area.width.saturating_sub(4));
    let popup_height = (app.default_mgr_options.len() as u16 + 5).min(area.height.saturating_sub(4));
    let x = (area.width.saturating_sub(popup_width)) / 2;
    let y = (area.height.saturating_sub(popup_height)) / 2;
    let popup_rect = Rect::new(x, y, popup_width, popup_height);

    frame.render_widget(Clear, popup_rect);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::Cyan))
        .title(" Set Default Package Manager ")
        .title_bottom(Line::from(vec![
            Span::styled(" Enter", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":save "),
            Span::styled("Esc", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)),
            Span::raw(":cancel "),
        ]));

    let inner = block.inner(popup_rect);
    frame.render_widget(block, popup_rect);

    let mut lines = Vec::new();
    lines.push(Line::from(Span::styled(
        "Choose package manager to set as default:",
        Style::default().fg(Color::Gray),
    )));
    lines.push(Line::raw(""));

    for (i, (bin, label)) in app.default_mgr_options.iter().enumerate() {
        let is_selected = i == app.default_mgr_selected;
        let is_current = bin == &app.current_default_mgr;

        let cursor_marker = if is_selected { "▶ " } else { "  " };
        let default_badge = if is_current { " [DEFAULT]" } else { "" };

        let style = if is_selected {
            Style::default()
                .fg(Color::Black)
                .bg(Color::Cyan)
                .add_modifier(Modifier::BOLD)
        } else if is_current {
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(Color::White)
        };

        lines.push(Line::from(vec![
            Span::styled(cursor_marker, style),
            Span::styled(format!("{label}{default_badge}"), style),
        ]));
    }

    let para = Paragraph::new(lines);
    frame.render_widget(para, inner);
}

fn draw_install_overlay(
    frame: &mut Frame,
    _app: &App,
    area: Rect,
    log_lines: &[String],
    progress: u8,
) {
    // Clear and draw overlay
    frame.render_widget(Clear, area);

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // progress bar
            Constraint::Min(1),     // log lines
        ])
        .split(area);

    // Progress bar
    let bar_width = chunks[0].width.saturating_sub(2) as usize;
    let filled = (bar_width * progress as usize) / 100;
    let bar_str = format!(
        "[{}{}] {}%",
        "█".repeat(filled),
        "░".repeat(bar_width.saturating_sub(filled)),
        progress
    );

    let prog_widget = Paragraph::new(bar_str)
        .style(Style::default().fg(Color::Cyan))
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .title(" Installing… "),
        );
    frame.render_widget(prog_widget, chunks[0]);

    // Log area
    let visible_height = chunks[1].height.saturating_sub(2) as usize;
    let start = log_lines.len().saturating_sub(visible_height);
    let visible: Vec<Line> = log_lines[start..]
        .iter()
        .map(|l| {
            let color = if l.starts_with('!') {
                Color::Red
            } else if l.contains("installed") || l.contains("upgraded") {
                Color::Green
            } else {
                Color::Gray
            };
            Line::from(Span::styled(l.as_str().to_owned(), Style::default().fg(color)))
        })
        .collect();

    let log_widget = Paragraph::new(visible)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .title(" Output (Ctrl-C to cancel) "),
        );
    frame.render_widget(log_widget, chunks[1]);
}
