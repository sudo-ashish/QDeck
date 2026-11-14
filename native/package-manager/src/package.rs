// package.rs — Core data types

use serde::{Deserialize, Serialize};

/// Where the package comes from
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum Source {
    Official(String), // repo name e.g. "core", "extra", "multilib"
    Aur,
}

impl Source {
    pub fn label(&self) -> &str {
        match self {
            Source::Official(_) => "OFFICIAL",
            Source::Aur => "AUR",
        }
    }

    pub fn repo(&self) -> &str {
        match self {
            Source::Official(r) => r.as_str(),
            Source::Aur => "aur",
        }
    }
}

/// A discovered package
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Package {
    pub name:         String,
    pub version:      String,
    pub description:  String,
    pub source:       Source,
    pub installed:    bool,
    pub dependencies: Vec<String>,
    /// AUR-specific metadata
    pub url:          Option<String>,
    pub maintainer:   Option<String>,
    pub votes:        Option<u64>,
    /// Search score (higher = better match)
    pub score:        i64,
}

impl Package {
    pub fn source_color_index(&self) -> u8 {
        match &self.source {
            Source::Official(_) => 2, // green
            Source::Aur => 3,         // yellow
        }
    }
}
