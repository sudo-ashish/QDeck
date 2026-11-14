// ui/status.rs — Footer / status bar (currently integrated into ui/mod.rs title_bottom)
// Reserved for future standalone status bar widget

pub struct StatusInfo {
    pub message: Option<String>,
    pub is_error: bool,
}
