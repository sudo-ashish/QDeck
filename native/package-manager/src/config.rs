// config.rs — User configuration (XDG-aware)

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Maximum number of results to display
    pub max_results: usize,
    /// Debounce delay for live search in milliseconds
    pub search_debounce_ms: u64,
    /// Show AUR results alongside official
    pub aur_enabled: bool,
    /// AUR RPC timeout seconds
    pub aur_timeout_secs: u64,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            max_results: 100,
            search_debounce_ms: 300,
            aur_enabled: true,
            aur_timeout_secs: 8,
        }
    }
}

impl Config {
    pub fn config_path() -> PathBuf {
        let base = std::env::var("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|_| {
                let mut h = dirs_home();
                h.push(".config");
                h
            });
        base.join("qdeck").join("pkg.toml")
    }

    pub fn load() -> Self {
        let path = Self::config_path();
        if path.exists() {
            if let Ok(contents) = std::fs::read_to_string(&path) {
                if let Ok(cfg) = toml::from_str::<Config>(&contents) {
                    return cfg;
                }
            }
        }
        Self::default()
    }
}

pub fn get_default_pkg_mgr() -> String {
    let dir = std::env::var("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| dirs_home().join(".config"))
        .join("qdeck");
    let path = dir.join("default-package-manager");
    if let Ok(s) = std::fs::read_to_string(path) {
        let trimmed = s.trim().to_string();
        if !trimmed.is_empty() {
            return trimmed;
        }
    }
    "qdeck-pkg".to_string()
}

pub fn set_default_pkg_mgr(name: &str) -> std::io::Result<()> {
    let dir = std::env::var("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| dirs_home().join(".config"))
        .join("qdeck");
    std::fs::create_dir_all(&dir)?;
    let path = dir.join("default-package-manager");
    std::fs::write(path, name)?;
    let _ = std::process::Command::new("notify-send")
        .args(["QDeck Package Manager", &format!("Default package manager set to: {name}")])
        .spawn();
    Ok(())
}

pub fn detect_available_package_managers() -> Vec<(String, String)> {
    let candidates = [
        ("qdeck-pkg", "QDeck Package Manager (Rust + Ratatui TUI)"),
        ("yay", "Yay (AUR & Pacman Helper)"),
        ("paru", "Paru (Feature-packed AUR Helper)"),
        ("pacman", "Pacman (Official Arch Linux Package Manager)"),
        ("pamac-manager", "Pamac (GUI Software Manager)"),
        ("bauh", "Bauh (Graphical Package Manager)"),
        ("octopi", "Octopi (Pacman GUI Frontend)"),
    ];

    let mut available = Vec::new();
    for (bin, label) in candidates {
        if bin == "qdeck-pkg" {
            available.push((bin.to_string(), label.to_string()));
        } else {
            let ok = std::process::Command::new("which")
                .arg(bin)
                .output()
                .map(|o| o.status.success())
                .unwrap_or(false);
            if ok {
                available.push((bin.to_string(), label.to_string()));
            }
        }
    }
    available
}

fn dirs_home() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/root"))
}
