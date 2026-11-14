// search.rs — Search engine: pacman -Ss + AUR RPC v5, dedup, fuzzy score

use crate::package::{Package, Source};
use fuzzy_matcher::{skim::SkimMatcherV2, FuzzyMatcher};
use serde::Deserialize;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::process::Command;
use tokio::time::{timeout, Duration};

// ── AUR RPC types ──────────────────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct AurResponse {
    results: Vec<AurPackage>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "PascalCase")]
struct AurPackage {
    name:        String,
    version:     String,
    description: Option<String>,
    #[serde(rename = "URL")]
    url:         Option<String>,
    maintainer:  Option<String>,
    num_votes:   Option<u64>,
    depends:     Option<Vec<String>>,
}

// ── Installed package cache ────────────────────────────────────────────────

/// Returns a set of installed package names (lowercase)
pub async fn installed_packages() -> HashMap<String, String> {
    let out = Command::new("pacman")
        .args(["-Q"])
        .output()
        .await
        .unwrap_or_else(|_| std::process::Output {
            status: std::process::ExitStatus::default(),
            stdout: vec![],
            stderr: vec![],
        });

    let mut map = HashMap::new();
    for line in String::from_utf8_lossy(&out.stdout).lines() {
        let mut parts = line.splitn(2, ' ');
        if let (Some(name), Some(ver)) = (parts.next(), parts.next()) {
            map.insert(name.to_lowercase(), ver.to_string());
        }
    }
    map
}

// ── Official (pacman -Ss) search ───────────────────────────────────────────

pub async fn search_official(query: &str) -> Vec<Package> {
    if query.is_empty() {
        return vec![];
    }

    let result = Command::new("pacman")
        .args(["-Ss", query])
        .output()
        .await;

    let out = match result {
        Ok(o) => o,
        Err(_) => return vec![],
    };

    // pacman -Ss exits 1 when no results — treat as empty
    parse_pacman_ss(&String::from_utf8_lossy(&out.stdout))
}

fn parse_pacman_ss(raw: &str) -> Vec<Package> {
    let mut packages = Vec::new();
    let mut lines = raw.lines().peekable();

    while let Some(line) = lines.next() {
        // Format: "repo/name version [flags]"
        if line.starts_with(' ') || line.is_empty() {
            continue;
        }

        let desc_line = lines.next().unwrap_or("").trim().to_string();

        // Parse "extra/neovim 0.10.3-1 [installed]"
        let mut parts = line.splitn(2, '/');
        let repo = match parts.next() {
            Some(r) => r.trim().to_string(),
            None => continue,
        };
        let rest = match parts.next() {
            Some(r) => r,
            None => continue,
        };

        let mut rest_parts = rest.splitn(2, ' ');
        let name = match rest_parts.next() {
            Some(n) => n.trim().to_string(),
            None => continue,
        };
        let version_rest = rest_parts.next().unwrap_or("").trim();

        // Version is first token; remainder may contain "[installed: X.Y.Z]" or "[installed]"
        let mut vp = version_rest.splitn(2, ' ');
        let version = vp.next().unwrap_or("").trim().to_string();
        let flags = vp.next().unwrap_or("");
        let installed = flags.contains("[installed") || flags.contains("[installed]");

        packages.push(Package {
            name,
            version,
            description: desc_line,
            source: Source::Official(repo),
            installed,
            dependencies: vec![],
            url: None,
            maintainer: None,
            votes: None,
            score: 0,
        });
    }

    packages
}

// ── AUR RPC search ─────────────────────────────────────────────────────────

pub async fn search_aur(query: &str, timeout_secs: u64) -> Result<Vec<Package>, String> {
    if query.is_empty() {
        return Ok(vec![]);
    }

    let url = format!(
        "https://aur.archlinux.org/rpc/v5/search/{}?by=name-desc",
        urlencoding::encode(query)
    );

    let client = reqwest::Client::builder()
        .user_agent("qdeck-pkg/0.1.0 (Arch Linux; +https://github.com/sudo-ashish/QDeck)")
        .timeout(Duration::from_secs(timeout_secs))
        .build()
        .map_err(|e| format!("HTTP client build error: {e}"))?;

    let resp_res = timeout(Duration::from_secs(timeout_secs + 2), client.get(&url).send()).await;

    if let Ok(Ok(resp)) = resp_res {
        if let Ok(aur) = resp.json::<AurResponse>().await {
            let packages: Vec<Package> = aur
                .results
                .into_iter()
                .map(|p| Package {
                    name:        p.name,
                    version:     p.version,
                    description: p.description.unwrap_or_default(),
                    source:      Source::Aur,
                    installed:   false, // filled in by merge()
                    dependencies: p.depends.unwrap_or_default(),
                    url:         p.url,
                    maintainer:  p.maintainer,
                    votes:       p.num_votes,
                    score:       0,
                })
                .collect();
            if !packages.is_empty() {
                return Ok(packages);
            }
        }
    }

    // Fallback via yay -Ss --aur
    let yay_pkgs = search_yay_aur(query).await;
    Ok(yay_pkgs)
}

// ── yay AUR fallback search ────────────────────────────────────────────────

pub async fn search_yay_aur(query: &str) -> Vec<Package> {
    if query.is_empty() {
        return vec![];
    }

    let result = Command::new("yay")
        .args(["-Ss", "--aur", query])
        .output()
        .await;

    let out = match result {
        Ok(o) => o,
        Err(_) => return vec![],
    };

    parse_yay_aur(&String::from_utf8_lossy(&out.stdout))
}

fn parse_yay_aur(raw: &str) -> Vec<Package> {
    let mut packages = Vec::new();
    let mut lines = raw.lines().peekable();

    while let Some(line) = lines.next() {
        if line.starts_with(' ') || line.is_empty() {
            continue;
        }

        let desc_line = lines.next().unwrap_or("").trim().to_string();

        let mut parts = line.splitn(2, '/');
        let _repo = parts.next();
        let rest = match parts.next() {
            Some(r) => r,
            None => continue,
        };

        let mut rest_parts = rest.splitn(2, ' ');
        let name = match rest_parts.next() {
            Some(n) => n.trim().to_string(),
            None => continue,
        };
        let version_rest = rest_parts.next().unwrap_or("").trim();
        let mut vp = version_rest.splitn(2, ' ');
        let version = vp.next().unwrap_or("").trim().to_string();

        packages.push(Package {
            name,
            version,
            description: desc_line,
            source: Source::Aur,
            installed: false,
            dependencies: vec![],
            url: None,
            maintainer: None,
            votes: None,
            score: 0,
        });
    }

    packages
}

// ── Merge + dedup + score ──────────────────────────────────────────────────

/// Merge official + AUR results, dedup by name (official wins), apply fuzzy scores
pub fn merge_and_score(
    query: &str,
    mut official: Vec<Package>,
    aur: Vec<Package>,
    installed: &HashMap<String, String>,
) -> Vec<Package> {
    let matcher = SkimMatcherV2::default();

    // Build name set from official results
    let official_names: std::collections::HashSet<String> =
        official.iter().map(|p| p.name.to_lowercase()).collect();

    // Merge AUR, skipping names already in official
    for mut pkg in aur {
        if !official_names.contains(&pkg.name.to_lowercase()) {
            // Fill installed status from pacman -Q cache
            pkg.installed = installed.contains_key(&pkg.name.to_lowercase());
            official.push(pkg);
        }
    }

    // Fill installed status for official packages too
    for pkg in &mut official {
        // pacman -Ss already sets installed; ensure AUR ones are covered
        if !pkg.installed {
            pkg.installed = installed.contains_key(&pkg.name.to_lowercase());
        }
        // Update version from installed cache if available
    }

    // Apply fuzzy scores
    for pkg in &mut official {
        let score = matcher
            .fuzzy_match(&pkg.name, query)
            .unwrap_or(0);
        // Boost installed packages slightly
        pkg.score = score + if pkg.installed { 20 } else { 0 };
    }

    // Sort: installed first, then by score descending, then alphabetical
    official.sort_by(|a, b| {
        b.installed
            .cmp(&a.installed)
            .then(b.score.cmp(&a.score))
            .then(a.name.cmp(&b.name))
    });

    official
}

// ── Package info (details) ─────────────────────────────────────────────────

/// Fetch detailed info for a single package via `pacman -Si` or `yay -Si`
pub async fn fetch_details(pkg: &Package) -> Package {
    let mut updated = pkg.clone();

    let output = match &pkg.source {
        Source::Official(_) => {
            Command::new("pacman")
                .args(["-Si", &pkg.name])
                .output()
                .await
        }
        Source::Aur => {
            Command::new("yay")
                .args(["-Si", &pkg.name])
                .output()
                .await
        }
    };

    let out = match output {
        Ok(o) => String::from_utf8_lossy(&o.stdout).to_string(),
        Err(_) => return updated,
    };

    for line in out.lines() {
        if let Some(rest) = line.strip_prefix("Depends On") {
            let deps: Vec<String> = rest
                .trim_start_matches([' ', '\t', ':'])
                .split_whitespace()
                .filter(|s| *s != "None")
                .map(|s| s.to_string())
                .collect();
            updated.dependencies = deps;
        }
        if let Some(rest) = line.strip_prefix("Version") {
            updated.version = rest
                .trim_start_matches([' ', '\t', ':'])
                .to_string();
        }
    }

    updated
}

// URL encoding helper (avoid adding a whole crate just for this)
mod urlencoding {
    pub fn encode(s: &str) -> String {
        let mut out = String::with_capacity(s.len());
        for b in s.bytes() {
            match b {
                b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9'
                | b'-' | b'_' | b'.' | b'~' => out.push(b as char),
                _ => {
                    out.push('%');
                    out.push_str(&format!("{:02X}", b));
                }
            }
        }
        out
    }
}
