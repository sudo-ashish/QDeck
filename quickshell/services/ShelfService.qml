import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property bool isOpen: false
    property ListModel items: ListModel { id: shelfModel }
    readonly property int count: items.count

    // Normalize input to a clean file:// URI string (file:///absolute/path/to/file)
    function normalizeUrl(rawUrl) {
        if (!rawUrl) return ""
        var str = String(rawUrl).trim()
        if (!str) return ""

        // If it starts with file://, ensure three slashes for absolute file paths
        if (str.startsWith("file://")) {
            if (!str.startsWith("file:///")) {
                str = "file:///" + str.slice(7).replace(/^\/+/, "")
            }
        } else if (str.startsWith("/")) {
            str = "file://" + str
        } else {
            // Strip any trailing CR/LF or quotes
            str = str.replace(/^['"]+|['"]+$/g, "").trim()
            if (str.startsWith("/")) {
                str = "file://" + str
            } else if (str.indexOf("/") !== -1) {
                str = "file:///" + str.replace(/^\/+/, "")
            } else {
                return ""
            }
        }

        // Clean trailing whitespace, CR, LF
        str = str.replace(/[\r\n]+$/, "")
        return str
    }

    function isImageFile(filename) {
        return /\.(png|jpe?g|webp|gif|svg|avif|bmp|ico)$/i.test(filename)
    }

    function resolveFileCategory(cleanPath, filename) {
        var ext = ""
        var dotIdx = filename.lastIndexOf(".")
        if (dotIdx !== -1) {
            ext = filename.slice(dotIdx + 1).toLowerCase()
        }
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "avif", "bmp"].indexOf(ext) !== -1) return "image"
        if (["mp4", "mkv", "webm", "avi", "mov", "flv"].indexOf(ext) !== -1) return "video"
        if (["mp3", "flac", "wav", "ogg", "m4a", "opus", "aac"].indexOf(ext) !== -1) return "audio"
        if (["zip", "tar", "gz", "bz2", "xz", "7z", "rar", "zst"].indexOf(ext) !== -1) return "archive"
        if (["pdf"].indexOf(ext) !== -1) return "pdf"
        if (["sh", "bash", "zsh", "py", "js", "ts", "qml", "json", "toml", "c", "cpp", "rs", "html", "css", "lua"].indexOf(ext) !== -1) return "code"
        if (["txt", "md", "doc", "docx", "odt", "rtf", "conf", "log"].indexOf(ext) !== -1) return "document"
        if (cleanPath && (cleanPath.indexOf("/bin/") !== -1 || ["makefile", "dockerfile", "gemfile", "vagrantfile"].indexOf(filename.toLowerCase()) !== -1)) return "code"
        return "folder"
    }

    function resolveFileIcon(cleanPath, filename) {
        var ext = ""
        var dotIdx = filename.lastIndexOf(".")
        if (dotIdx !== -1) {
            ext = filename.slice(dotIdx + 1).toLowerCase()
        }
        if (["png", "jpg", "jpeg", "webp", "gif", "svg", "avif", "bmp"].indexOf(ext) !== -1) return Icons.wallpaper
        if (["mp4", "mkv", "webm", "avi", "mov", "flv"].indexOf(ext) !== -1) return "movie"
        if (["mp3", "flac", "wav", "ogg", "m4a", "opus", "aac"].indexOf(ext) !== -1) return Icons.music
        if (["zip", "tar", "gz", "bz2", "xz", "7z", "rar", "zst"].indexOf(ext) !== -1) return "folder_zip"
        if (["pdf"].indexOf(ext) !== -1) return "description"
        if (["sh", "bash", "zsh", "py", "js", "ts", "qml", "json", "toml", "c", "cpp", "rs", "html", "css", "lua"].indexOf(ext) !== -1) return Icons.terminal
        if (["txt", "md", "doc", "docx", "odt", "rtf", "conf", "log"].indexOf(ext) !== -1) return "description"
        if (cleanPath && (cleanPath.indexOf("/bin/") !== -1 || ["makefile", "dockerfile", "gemfile", "vagrantfile"].indexOf(filename.toLowerCase()) !== -1)) return Icons.terminal
        return Icons.folder
    }

    function hasUrl(cleanUrl) {
        for (var i = 0; i < items.count; i++) {
            if (items.get(i).filePath === cleanUrl) return true
        }
        return false
    }

    function addUrl(rawUrl) {
        var cleanUrl = root.normalizeUrl(rawUrl)
        if (!cleanUrl) return false
        if (root.hasUrl(cleanUrl)) return false

        var unquoted = decodeURIComponent(cleanUrl.replace(/^file:\/\//, ""))
        var name = unquoted.split("/").pop() || unquoted
        var isImg = root.isImageFile(name)
        var icon = root.resolveFileIcon(cleanUrl, name)
        var category = root.resolveFileCategory(cleanUrl, name)

        items.append({
            filePath: cleanUrl,
            fileName: name,
            isImage: isImg,
            fileIcon: icon,
            fileCategory: category
        })
        return true
    }

    function addUrls(urlList) {
        if (!urlList) return false
        var addedAny = false
        for (var i = 0; i < urlList.length; i++) {
            var item = urlList[i]
            var urlStr = (item && item.toString) ? item.toString() : String(item || "")
            if (urlStr.trim().length > 0) {
                if (root.addUrl(urlStr)) {
                    addedAny = true
                }
            }
        }
        return addedAny
    }

    function removeAt(index) {
        if (index >= 0 && index < items.count) {
            items.remove(index)
        }
    }

    function clear() {
        items.clear()
    }

    function open() {
        root.isOpen = true
    }

    function close() {
        root.isOpen = false
    }

    function toggle() {
        root.isOpen = !root.isOpen
    }

    function getItemsJson() {
        var arr = []
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            arr.push({
                filePath: it.filePath,
                fileName: it.fileName,
                isImage: it.isImage,
                fileIcon: it.fileIcon,
                fileCategory: it.fileCategory || "folder"
            })
        }
        return JSON.stringify(arr)
    }

    // IPC Handler for controlling Staging Shelf via CLI (qs ipc call shelf ...)
    property IpcHandler ipcHandler: IpcHandler {
        target: "shelf"

        function toggle(): string {
            root.toggle()
            return root.isOpen ? "open" : "closed"
        }

        function open(): string {
            root.open()
            return "open"
        }

        function close(): string {
            root.close()
            return "closed"
        }

        function clear(): string {
            root.clear()
            return "cleared"
        }

        function count(): string {
            return String(root.count)
        }

        function list(): string {
            return root.getItemsJson()
        }

        function remove(indexStr: string): string {
            root.removeAt(parseInt(indexStr))
            return "ok"
        }

        function add(path: string): string {
            var ok = root.addUrl(path)
            return ok ? "added" : "skipped"
        }
    }
}
