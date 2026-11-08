// Helper functions for Launcher search, actions, and history management

function normalizeText(text) {
    return String(text || "").toLowerCase().trim();
}

var KNOWN_ICON_MAP = {
    "whatsapp": "file:///home/pear/.local/share/icons/hicolor/256x256/apps/whatsapp.png",
    "antigravity": "file:///usr/share/pixmaps/antigravity.png",
    "antigravity-ide": "file:///usr/share/pixmaps/antigravity-ide.png",
    "antigravity-ide-url-handler": "file:///usr/share/pixmaps/antigravity-ide.png",
    "nwg-look": "file:///usr/share/pixmaps/nwg-look.svg",
    "pinentry": "file:///usr/share/pixmaps/pinentry.png",
    "spotify-launcher": "file:///usr/share/pixmaps/spotify-launcher.png",
    "network-wired": "file:///usr/share/icons/Adwaita/symbolic/devices/network-wired-symbolic.svg",
    "multimedia-photo-viewer": "file:///usr/share/icons/Adwaita/symbolic/categories/applications-multimedia-symbolic.svg"
};

function resolveIcon(icon) {
    if (!icon || icon === "") return "";
    var s = String(icon).trim();
    if (s.startsWith("file://") || s.startsWith("image://")) return s;
    if (s.startsWith("/")) return "file://" + s;

    var cleaned = s.replace(/\.(png|svg|xpm|ico)$/i, "");
    var lower = cleaned.toLowerCase();
    if (KNOWN_ICON_MAP[lower]) {
        return KNOWN_ICON_MAP[lower];
    }
    if (KNOWN_ICON_MAP[cleaned]) {
        return KNOWN_ICON_MAP[cleaned];
    }

    return "image://icon/" + cleaned;
}

var BUILTIN_ACTIONS = [
    {
        id: "act-vol-50",
        name: "Set volume to 50",
        type: "action",
        iconGlyph: "tune",
        category: "Audio",
        defaultMeta: "56 minutes ago",
        cmd: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.50 || pamixer --set-volume 50",
        keywords: ["volume", "sound", "audio", "speaker", "50", "set volume"]
    },
    {
        id: "act-dnd",
        name: "Turn on do not disturb",
        type: "action",
        iconGlyph: "phone",
        category: "System",
        defaultMeta: "S24",
        cmd: "makoctl mode -a dnd || swaync-client -d -s || true",
        keywords: ["dnd", "do not disturb", "notifications", "silent", "quiet", "s24"]
    },
    {
        id: "act-vol-100",
        name: "Set volume to 100",
        type: "action",
        iconGlyph: "volumeHigh",
        category: "Audio",
        defaultMeta: "1 hour ago",
        cmd: "wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 || pamixer --set-volume 100",
        keywords: ["volume", "sound", "audio", "max", "100", "loud"]
    },
    {
        id: "act-dnd-off",
        name: "Turn off do not disturb",
        type: "action",
        iconGlyph: "bell",
        category: "System",
        defaultMeta: "2 hours ago",
        cmd: "makoctl mode -r dnd || swaync-client -d -s || true",
        keywords: ["dnd", "notifications", "sound", "resume"]
    },
    {
        id: "act-lock",
        name: "Lock screen",
        type: "action",
        iconGlyph: "lock",
        category: "System",
        defaultMeta: "Security",
        cmd: "loginctl lock-session || hyprlock",
        keywords: ["lock", "screen", "session", "sleep"]
    },
    {
        id: "act-theme",
        name: "Theme Switcher",
        type: "action",
        iconGlyph: "palette",
        category: "Appearance",
        defaultMeta: "Personalize",
        cmd: "qdeck powermenu theme",
        keywords: ["theme", "style", "colors", "appearance"]
    },
    {
        id: "act-wallpaper",
        name: "Wallpaper Picker",
        type: "action",
        iconGlyph: "wallpaper",
        category: "Desktop",
        defaultMeta: "Wallpaper",
        cmd: "qdeck powermenu wallpaper",
        keywords: ["wallpaper", "background", "image", "photo"]
    },
    {
        id: "act-shelf",
        name: "Toggle Staging Shelf",
        type: "action",
        iconGlyph: "folder",
        category: "Files",
        defaultMeta: "Drop Shelf",
        cmd: "qs ipc call shelf toggle",
        keywords: ["shelf", "drop", "staging", "dnd", "drag", "files", "clipboard", "tray"]
    },
    {
        id: "act-terminal",
        name: "Open Terminal",
        type: "action",
        iconGlyph: "terminal",
        category: "System",
        defaultMeta: "Terminal",
        cmd: "kitty",
        keywords: ["terminal", "console", "shell", "kitty", "bash", "zsh"]
    },
    {
        id: "act-screenshot",
        name: "Take Screenshot",
        type: "action",
        iconGlyph: "screenshot",
        category: "Utility",
        defaultMeta: "Screenshot",
        cmd: "grimblast copysave area",
        keywords: ["screenshot", "snip", "capture", "screen", "area"]
    },
    {
        id: "act-reboot",
        name: "Restart system",
        type: "action",
        iconGlyph: "reboot",
        category: "Power",
        defaultMeta: "System",
        cmd: "systemctl reboot",
        keywords: ["reboot", "restart", "system"]
    },
    {
        id: "act-shutdown",
        name: "Shut down system",
        type: "action",
        iconGlyph: "power",
        category: "Power",
        defaultMeta: "System",
        cmd: "systemctl poweroff",
        keywords: ["shutdown", "power", "turn off", "halt"]
    }
];

function getAppCategory(app) {
    if (!app) return "App";
    var raw = "";
    try {
        if (app.categories) {
            if (Array.isArray(app.categories)) raw = app.categories.join(" ").toLowerCase();
            else raw = String(app.categories).toLowerCase();
        }
    } catch (e) {}

    var id = String(app.id || "").toLowerCase();
    var name = String(app.name || "").toLowerCase();
    var generic = String(app.genericName || "").toLowerCase();
    var comment = String(app.comment || "").toLowerCase();
    var all = raw + " " + id + " " + name + " " + generic + " " + comment;

    if (all.indexOf("setting") !== -1 || all.indexOf("preference") !== -1 || all.indexOf("system") !== -1 ||
        all.indexOf("config") !== -1 || all.indexOf("monitor") !== -1 || all.indexOf("terminal") !== -1 ||
        all.indexOf("nautilus") !== -1 || all.indexOf("files") !== -1 || all.indexOf("pavucontrol") !== -1 ||
        all.indexOf("nwg-look") !== -1 || all.indexOf("look") !== -1 || all.indexOf("btop") !== -1 ||
        all.indexOf("store") !== -1 || all.indexOf("hardware") !== -1) {
        return "System";
    }
    return "App";
}

function formatRelativeTime(ts, now) {
    if (!ts || isNaN(ts) || ts <= 0) return "";
    var current = now || Date.now();
    var diffMs = current - ts;
    if (diffMs < 0) diffMs = 0;
    var diffSec = Math.floor(diffMs / 1000);
    var diffMin = Math.floor(diffSec / 60);
    var diffHours = Math.floor(diffMin / 60);
    var diffDays = Math.floor(diffHours / 24);

    if (diffMin < 1) return "just now";
    if (diffMin < 60) return diffMin + (diffMin === 1 ? " minute ago" : " minutes ago");
    if (diffHours < 24) return diffHours + (diffHours === 1 ? " hour ago" : " hours ago");
    if (diffDays < 30) return diffDays + (diffDays === 1 ? " day ago" : " days ago");
    var diffMonths = Math.floor(diffDays / 30);
    return diffMonths + (diffMonths === 1 ? " month ago" : " months ago");
}

function filterAll(apps, query, historyMap) {
    var raw = String(query || "");
    var rawTrimmed = raw.trim();
    var isAction = rawTrimmed.startsWith(">");
    var history = historyMap || {};
    var now = Date.now();
    var allItems = [];

    if (isAction) {
        // Action Mode: trigger with > or > <search>
        var actionTerm = rawTrimmed.replace(/^>\s*/, "").toLowerCase();

        for (var a = 0; a < BUILTIN_ACTIONS.length; a++) {
            var act = BUILTIN_ACTIONS[a];
            var actLastUsed = history[act.id] || 0;
            var actMeta = "";

            if (actLastUsed) {
                actMeta = formatRelativeTime(actLastUsed, now) + " • " + act.category;
            } else {
                actMeta = "Action • " + act.category;
            }

            var actScore = 0;
            if (!actionTerm) {
                // User typed ">" or "> ": show all actions
                if (history[act.id]) {
                    actScore = 10000 + Math.max(0, 5000 - Math.floor((now - history[act.id]) / 60000));
                } else {
                    actScore = 1000 - a * 10;
                }
            } else {
                var actNameLower = act.name.toLowerCase();
                var actKeywordsLower = (act.keywords || []).join(" ").toLowerCase();
                var actCategoryLower = String(act.category || "").toLowerCase();

                if (actNameLower === actionTerm) actScore += 2000;
                else if (actNameLower.startsWith(actionTerm)) actScore += 1000;
                else if (actNameLower.indexOf(actionTerm) !== -1) actScore += 500;
                else if (actKeywordsLower.indexOf(actionTerm) !== -1) actScore += 300;
                else if (actCategoryLower.indexOf(actionTerm) !== -1) actScore += 150;

                if (actScore > 0 && history[act.id]) {
                    actScore += 50;
                }
            }

            if (actScore > 0) {
                allItems.push({
                    type: "action",
                    id: act.id,
                    name: act.name,
                    icon: "",
                    iconGlyph: act.iconGlyph,
                    category: act.category,
                    metaText: actMeta,
                    score: actScore,
                    lastUsed: actLastUsed,
                    entry: null,
                    cmd: act.cmd
                });
            }
        }
    } else {
        // Normal Apps Mode: only show and search desktop applications
        var q = normalizeText(query);

        if (apps && apps.length) {
            for (var i = 0; i < apps.length; i++) {
                var app = apps[i];
                if (!app || app.noDisplay) continue;

                var name = String(app.name || app.id || "").trim();
                if (!name) continue;

                var id = String(app.id || "").trim();
                var category = getAppCategory(app);
                var lastUsed = history[id] || 0;

                // Generate deterministic fallback timestamp if not in history so relative time displays neatly
                if (!lastUsed) {
                    var hash = 0;
                    for (var h = 0; h < name.length; h++) hash = (hash * 31 + name.charCodeAt(h)) & 0xffffff;
                    var daysAgo = 1 + (Math.abs(hash) % 4);
                    lastUsed = now - (daysAgo * 86400000 + (Math.abs(hash) % 3600000));
                }

                var metaText = formatRelativeTime(lastUsed, now) + " • " + category;

                var keywords = "";
                try {
                    if (app.keywords && Array.isArray(app.keywords)) {
                        keywords = app.keywords.join(" ");
                    }
                } catch (e) {}

                var generic = String(app.genericName || "").trim();
                var comment = String(app.comment || "").trim();

                var score = 0;
                if (!q) {
                    if (history[id]) {
                        score = 10000 + Math.max(0, 5000 - Math.floor((now - history[id]) / 60000));
                    } else {
                        score = Math.max(1, 1000 - Math.floor((now - lastUsed) / 3600000));
                    }
                } else {
                    var nameLower = name.toLowerCase();
                    var idLower = id.toLowerCase();
                    var genericLower = generic.toLowerCase();
                    var commentLower = comment.toLowerCase();
                    var keywordsLower = keywords.toLowerCase();

                    if (nameLower === q) score += 2000;
                    else if (nameLower.startsWith(q)) score += 1000;
                    else if (nameLower.indexOf(q) !== -1) score += 500;
                    else if (idLower.startsWith(q)) score += 400;
                    else if (idLower.indexOf(q) !== -1) score += 250;
                    else if (genericLower.indexOf(q) !== -1) score += 150;
                    else if (keywordsLower.indexOf(q) !== -1) score += 100;
                    else if (commentLower.indexOf(q) !== -1) score += 50;

                    // Acronym search
                    var words = nameLower.split(/[\s\-_]+/);
                    var acronym = "";
                    for (var w = 0; w < words.length; w++) {
                        if (words[w]) acronym += words[w].charAt(0);
                    }
                    if (acronym.indexOf(q) !== -1) score += 80;

                    if (score > 0 && history[id]) {
                        score += 50;
                    }
                }

                if (score > 0) {
                    allItems.push({
                        type: "app",
                        id: id,
                        name: name,
                        icon: resolveIcon(app.icon),
                        iconGlyph: "",
                        category: category,
                        metaText: metaText,
                        score: score,
                        lastUsed: lastUsed,
                        entry: app,
                        cmd: ""
                    });
                }
            }
        }
    }

    allItems.sort(function(itemA, itemB) {
        if (itemB.score !== itemA.score) {
            return itemB.score - itemA.score;
        }
        return itemA.name.localeCompare(itemB.name);
    });

    return allItems;
}

// Apps mode filtering and sorting (backward compatibility)
function filterApps(apps, query) {
    return filterAll(apps, query, {});
}

// Windows mode parsing
function parseWindows(rawJson, query) {
    var q = normalizeText(query);
    var results = [];
    if (!rawJson) return results;

    var list = [];
    try {
        list = JSON.parse(rawJson);
    } catch (e) {
        return results;
    }

    if (!Array.isArray(list)) return results;

    for (var i = 0; i < list.length; i++) {
        var w = list[i];
        if (!w || !w.mapped || w.hidden) continue;

        var title = String(w.title || "").trim();
        var winClass = String(w.class || w.initialClass || "").trim();
        var wsName = w.workspace ? String(w.workspace.name || w.workspace.id || "") : "";
        var addr = String(w.address || "");

        var name = title || winClass || "Window";
        var generic = winClass + (wsName ? " · WS " + wsName : "");

        var match = !q || name.toLowerCase().indexOf(q) !== -1 || winClass.toLowerCase().indexOf(q) !== -1 || wsName.toLowerCase().indexOf(q) !== -1;
        if (match) {
            results.push({
                type: "window",
                id: addr,
                address: addr,
                name: name,
                generic: generic,
                icon: resolveIcon(winClass.toLowerCase()),
                workspaceId: w.workspace ? w.workspace.id : 1
            });
        }
    }

    return results;
}

// Run commands filtering
function filterCommands(binaries, query) {
    var q = normalizeText(query);
    var results = [];

    if (query && query.trim().length > 0) {
        results.push({
            type: "command",
            id: "cmd-custom",
            name: query.trim(),
            generic: "Run Command",
            icon: resolveIcon("system-run"),
            cmd: query.trim()
        });
    }

    if (!binaries || !binaries.length) return results;

    for (var i = 0; i < binaries.length; i++) {
        var b = binaries[i];
        if (!b) continue;
        if (!q || b.toLowerCase().indexOf(q) !== -1) {
            if (query && b.toLowerCase() === q) continue;
            results.push({
                type: "command",
                id: "cmd-" + b,
                name: b,
                generic: "Command",
                icon: resolveIcon("utilities-terminal"),
                cmd: b
            });
            if (results.length >= 50) break;
        }
    }

    return results;
}

// Files mode parsing
function parseFiles(rawLines, query) {
    var q = normalizeText(query);
    var results = [];
    if (!rawLines) return results;

    var home = "";
    try {
        if (typeof Quickshell !== "undefined" && Quickshell.env) {
            home = Quickshell.env("HOME") || "";
        }
    } catch (e) {}

    var lines = String(rawLines).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line) continue;
        var parts = line.split("\t");
        var filename = parts[0] || "";
        var fullpath = parts[1] || line;
        var isDir = parts[2] === "d";

        if (!filename && fullpath) {
            var slashIdx = fullpath.lastIndexOf("/");
            filename = slashIdx >= 0 ? fullpath.substring(slashIdx + 1) : fullpath;
        }

        if (!filename) continue;

        if (!q || filename.toLowerCase().indexOf(q) !== -1 || fullpath.toLowerCase().indexOf(q) !== -1) {
            var displayPath = home ? fullpath.replace(home, "~") : fullpath.replace(/^\/home\/[^\/]+/, "~");
            results.push({
                type: "file",
                id: fullpath,
                name: filename,
                generic: displayPath,
                icon: isDir ? resolveIcon("folder") : resolveIcon("text-x-generic"),
                path: fullpath,
                isDir: isDir
            });
            if (results.length >= 50) break;
        }
    }

    return results;
}

if (typeof module !== "undefined") {
    module.exports = {
        normalizeText: normalizeText,
        resolveIcon: resolveIcon,
        BUILTIN_ACTIONS: BUILTIN_ACTIONS,
        getAppCategory: getAppCategory,
        formatRelativeTime: formatRelativeTime,
        filterAll: filterAll,
        filterApps: filterApps,
        parseWindows: parseWindows,
        filterCommands: filterCommands,
        parseFiles: parseFiles
    };
}
