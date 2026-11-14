// ui/details.rs — Package detail panel

use crate::app::{App, FocusedPanel};
use crate::package::Source;
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph, Wrap},
    Frame,
};

pub fn draw(frame: &mut Frame, app: &App, area: Rect) {
    let focused = app.focused == FocusedPanel::Details;
    let border_color = if focused { Color::Cyan } else { Color::DarkGray };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(border_color))
        .title(" Package Details ");

    let Some(pkg) = app.selected_package() else {
        let empty = Paragraph::new("No package selected.\nUse ↑↓ to navigate results.")
            .style(Style::default().fg(Color::DarkGray))
            .block(block);
        frame.render_widget(empty, area);
        return;
    };

    let inner = block.inner(area);
    frame.render_widget(block, area);

    // Build detail lines
    let (source_label, source_color) = match &pkg.source {
        Source::Official(repo) => (format!("OFFICIAL [{repo}]"), Color::Green),
        Source::Aur => ("AUR".to_string(), Color::Yellow),
    };

    let installed_line = if pkg.installed {
        Line::from(vec![
            kv_key("Status:  "),
            Span::styled("✓ Installed", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
        ])
    } else {
        Line::from(vec![
            kv_key("Status:  "),
            Span::styled("Not installed", Style::default().fg(Color::DarkGray)),
        ])
    };

    let mut lines: Vec<Line> = vec![
        Line::from(vec![
            Span::styled(
                &pkg.name,
                Style::default()
                    .fg(Color::White)
                    .add_modifier(Modifier::BOLD),
            ),
        ]),
        Line::raw(""),
        Line::from(vec![
            kv_key("Source:  "),
            Span::styled(source_label, Style::default().fg(source_color).add_modifier(Modifier::BOLD)),
        ]),
        Line::from(vec![
            kv_key("Version: "),
            Span::styled(&pkg.version, Style::default().fg(Color::White)),
        ]),
        installed_line,
    ];

    if let Some(url) = &pkg.url {
        lines.push(Line::from(vec![
            kv_key("URL:     "),
            Span::styled(url, Style::default().fg(Color::Blue)),
        ]));
    }

    if let Some(maintainer) = &pkg.maintainer {
        lines.push(Line::from(vec![
            kv_key("Author:  "),
            Span::raw(maintainer),
        ]));
    }

    if let Some(votes) = pkg.votes {
        lines.push(Line::from(vec![
            kv_key("Votes:   "),
            Span::raw(format!("{votes}")),
        ]));
    }

    lines.push(Line::raw(""));
    lines.push(Line::from(Span::styled(
        "Description",
        Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
    )));
    // Word-wrap description
    for line in wrap_text(&pkg.description, inner.width as usize) {
        lines.push(Line::from(Span::styled(line, Style::default().fg(Color::Gray))));
    }

    if !pkg.dependencies.is_empty() {
        lines.push(Line::raw(""));
        lines.push(Line::from(Span::styled(
            "Dependencies",
            Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
        )));
        let dep_str = pkg.dependencies.join(", ");
        for line in wrap_text(&dep_str, inner.width as usize) {
            lines.push(Line::from(Span::styled(
                line,
                Style::default().fg(Color::DarkGray),
            )));
        }
    }

    // Action hints at bottom
    lines.push(Line::raw(""));
    let action_line = if pkg.installed {
        Line::from(vec![
            Span::styled(" u ", Style::default().fg(Color::Black).bg(Color::Red)),
            Span::raw(" Remove"),
        ])
    } else {
        Line::from(vec![
            Span::styled(" i ", Style::default().fg(Color::Black).bg(Color::Green)),
            Span::raw(" Install"),
        ])
    };
    lines.push(action_line);

    // Split area: detail text above, action hint below
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(1)])
        .split(inner);

    let para = Paragraph::new(lines)
        .wrap(Wrap { trim: true });
    frame.render_widget(para, chunks[0]);
}

fn kv_key(s: &'static str) -> Span<'static> {
    Span::styled(s, Style::default().fg(Color::DarkGray))
}

fn wrap_text(text: &str, width: usize) -> Vec<String> {
    if width == 0 {
        return vec![text.to_string()];
    }
    let mut result = Vec::new();
    let mut current = String::new();

    for word in text.split_whitespace() {
        if current.is_empty() {
            current = word.to_string();
        } else if current.len() + 1 + word.len() <= width {
            current.push(' ');
            current.push_str(word);
        } else {
            result.push(current.clone());
            current = word.to_string();
        }
    }
    if !current.is_empty() {
        result.push(current);
    }
    result
}
