// ui/search_bar.rs — Search input widget

use crate::app::{App, FocusedPanel};
use ratatui::{
    layout::Rect,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, BorderType, Borders, Paragraph},
    Frame,
};

pub fn draw(frame: &mut Frame, app: &App, area: Rect) {
    let focused = app.focused == FocusedPanel::Search;
    let border_color = if focused { Color::Cyan } else { Color::DarkGray };

    let query = &app.search_query;

    // Build text with cursor block
    let display = if focused {
        format!("{query}█")
    } else if query.is_empty() {
        "Search packages… (press / to focus)".to_string()
    } else {
        query.clone()
    };

    let text_color = if focused || !query.is_empty() {
        Color::White
    } else {
        Color::DarkGray
    };

    let title: Line = Line::from(vec![
        Span::raw(" "),
        Span::styled(
            "󰍉 ",
            Style::default().fg(Color::Cyan),
        ),
        Span::raw("Search "),
    ]);

    let widget = Paragraph::new(Line::from(Span::styled(
        display,
        Style::default()
            .fg(text_color)
            .add_modifier(if focused { Modifier::BOLD } else { Modifier::empty() }),
    )))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(border_color))
            .title(title),
    );

    frame.render_widget(widget, area);
}
