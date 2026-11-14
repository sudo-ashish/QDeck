// ui/layout.rs — Responsive terminal geometry

use ratatui::layout::{Constraint, Direction, Layout, Rect};

pub struct Geometry {
    pub search:     Rect,
    pub results:    Rect,
    pub details:    Option<Rect>,
    pub has_details: bool,
}

pub fn compute(area: Rect, terminal_width: u16) -> Geometry {
    // Split vertically: search bar (3 lines) + content area
    let vertical = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // search bar
            Constraint::Min(1),    // content
        ])
        .split(area);

    let search = vertical[0];
    let content = vertical[1];

    // Wide enough to show side-by-side details?
    let has_details = terminal_width >= 100;

    if has_details {
        let horizontal = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(58),
                Constraint::Percentage(42),
            ])
            .split(content);

        Geometry {
            search,
            results: horizontal[0],
            details: Some(horizontal[1]),
            has_details: true,
        }
    } else {
        Geometry {
            search,
            results: content,
            details: None,
            has_details: false,
        }
    }
}
