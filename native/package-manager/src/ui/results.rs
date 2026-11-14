// ui/results.rs — Package results list widget

use crate::app::{App, FocusedPanel};
use crate::package::Source;
use ratatui::{
    layout::{Constraint, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Cell, Row, Table, TableState},
    Frame,
};

pub fn draw(frame: &mut Frame, app: &App, area: Rect) {
    let focused = app.focused == FocusedPanel::Results;
    let border_color = if focused { Color::Cyan } else { Color::DarkGray };

    let packages = &app.results;

    let count_label = if app.searching {
        " Searching…".to_string()
    } else {
        format!(" {} packages", packages.len())
    };

    let rows: Vec<Row> = packages
        .iter()
        .map(|pkg| {
            // Source badge
            let (badge_text, badge_color) = match &pkg.source {
                Source::Official(_) => (" OFFICIAL ", Color::Green),
                Source::Aur => (" AUR ", Color::Yellow),
            };

            // Installed indicator
            let inst_span = if pkg.installed {
                Span::styled("✓ ", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))
            } else {
                Span::raw("  ")
            };

            let name_line = Line::from(vec![
                inst_span,
                Span::styled(
                    pkg.name.clone(),
                    Style::default()
                        .fg(Color::White)
                        .add_modifier(Modifier::BOLD),
                ),
            ]);

            let desc_line = Line::from(Span::styled(
                truncate(&pkg.description, 60),
                Style::default().fg(Color::Gray),
            ));

            let badge_cell = Cell::from(Line::from(Span::styled(
                badge_text,
                Style::default()
                    .fg(Color::Black)
                    .bg(badge_color)
                    .add_modifier(Modifier::BOLD),
            )));

            let ver_cell = Cell::from(Span::styled(
                truncate(&pkg.version, 18),
                Style::default().fg(Color::DarkGray),
            ));

            let name_col = Cell::from(vec![name_line, desc_line]);

            Row::new(vec![name_col, badge_cell, ver_cell]).height(2)
        })
        .collect();

    let header = Row::new(vec![
        Cell::from(Span::styled(
            "Package",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        )),
        Cell::from(Span::styled(
            "Source",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        )),
        Cell::from(Span::styled(
            "Version",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        )),
    ])
    .height(1)
    .style(Style::default().bg(Color::DarkGray));

    let col_widths = [
        Constraint::Min(30),
        Constraint::Length(10),
        Constraint::Length(20),
    ];

    let table = Table::new(rows, col_widths)
        .header(header)
        .row_highlight_style(
            Style::default()
                .bg(Color::Blue)
                .fg(Color::White)
                .add_modifier(Modifier::BOLD),
        )
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(border_color))
                .title(format!(" Results{count_label} ")),
        );

    let mut state = TableState::default();
    if !packages.is_empty() {
        state.select(Some(app.selected_index));
    }

    frame.render_stateful_widget(table, area, &mut state);
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        s.to_string()
    } else {
        let mut out: String = s.chars().take(max.saturating_sub(1)).collect();
        out.push('…');
        out
    }
}
