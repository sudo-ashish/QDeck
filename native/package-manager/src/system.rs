// system.rs — System dependency checks

use std::process::Command;

pub struct SystemInfo {
    pub yay_available:   bool,
    pub kitty_available: bool,
    pub yay_path:        Option<String>,
}

impl SystemInfo {
    pub fn detect() -> Self {
        SystemInfo {
            yay_available:   command_exists("yay"),
            kitty_available: command_exists("kitty"),
            yay_path:        which("yay"),
        }
    }
}

fn command_exists(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn which(cmd: &str) -> Option<String> {
    let out = Command::new("which").arg(cmd).output().ok()?;
    if out.status.success() {
        Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
    } else {
        None
    }
}
