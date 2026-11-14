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

fn dirs_home() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/root"))
}
