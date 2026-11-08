import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    property bool isOpen: false
    property ListModel items: ListModel { id: shelfModel }
    readonly property int count: items.count
    property int selectedCount: 0
    property int lastSelectedIndex: -1

    function updateSelectedCount() {
        var c = 0
        for (var i = 0; i < items.count; i++) {
            if (items.get(i).selected) c++
        }
        root.selectedCount = c
    }

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
            fileCategory: category,
            selected: false
        })
        root.updateSelectedCount()
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
            if (root.lastSelectedIndex >= items.count) {
                root.lastSelectedIndex = items.count - 1
            }
            root.updateSelectedCount()
        }
    }

    function clear() {
        items.clear()
        root.lastSelectedIndex = -1
        root.selectedCount = 0
    }

    function setSelected(index, val) {
        if (index >= 0 && index < items.count) {
            items.setProperty(index, "selected", !!val)
            root.updateSelectedCount()
        }
    }

    function selectAll() {
        for (var i = 0; i < items.count; i++) {
            items.setProperty(i, "selected", true)
        }
        root.updateSelectedCount()
    }

    function clearSelection() {
        for (var i = 0; i < items.count; i++) {
            items.setProperty(i, "selected", false)
        }
        root.lastSelectedIndex = -1
        root.updateSelectedCount()
    }

    function toggleItem(index) {
        if (index < 0 || index >= items.count) return
        var cur = !!items.get(index).selected
        items.setProperty(index, "selected", !cur)
        root.lastSelectedIndex = index
        root.updateSelectedCount()
    }

    function toggleSelection(index, modifiers) {
        if (index < 0 || index >= items.count) return
        var isShift = !!(modifiers & Qt.ShiftModifier)
        var isCtrl = !!(modifiers & Qt.ControlModifier)

        if (isShift && root.lastSelectedIndex >= 0 && root.lastSelectedIndex < items.count) {
            var start = Math.min(root.lastSelectedIndex, index)
            var end = Math.max(root.lastSelectedIndex, index)
            if (!isCtrl) {
                for (var i = 0; i < items.count; i++) {
                    items.setProperty(i, "selected", i >= start && i <= end)
                }
            } else {
                for (var j = start; j <= end; j++) {
                    items.setProperty(j, "selected", true)
                }
            }
        } else if (isCtrl) {
            var cur = !!items.get(index).selected
            items.setProperty(index, "selected", !cur)
            root.lastSelectedIndex = index
        } else {
            // Plain click:
            // If already in multi-select mode (selectedCount > 0), clicking toggles this item
            // If not in multi-select mode (selectedCount == 0), select this item
            if (root.selectedCount > 0) {
                var curState = !!items.get(index).selected
                items.setProperty(index, "selected", !curState)
            } else {
                for (var k = 0; k < items.count; k++) {
                    items.setProperty(k, "selected", k === index)
                }
            }
            root.lastSelectedIndex = index
        }
        root.updateSelectedCount()
    }

    function removeSelected() {
        for (var i = items.count - 1; i >= 0; i--) {
            if (items.get(i).selected) {
                items.remove(i)
            }
        }
        root.lastSelectedIndex = -1
        root.updateSelectedCount()
    }

    function getSelectedUris() {
        var uris = []
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            if (it.selected) {
                uris.push(it.filePath)
            }
        }
        return uris
    }

    function getSelectedItems() {
        var list = []
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            if (it.selected) {
                list.push({
                    index: i,
                    filePath: it.filePath,
                    fileName: it.fileName,
                    isImage: it.isImage,
                    fileIcon: it.fileIcon,
                    fileCategory: it.fileCategory || "folder"
                })
            }
        }
        return list
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

        function removeSelected(): string {
            root.removeSelected()
            return "ok"
        }

        function selectAll(): string {
            root.selectAll()
            return "ok"
        }

        function toggleItem(indexStr: string): string {
            var idx = parseInt(indexStr, 10)
            if (!isNaN(idx)) {
                root.toggleItem(idx)
                return "ok"
            }
            return "error"
        }

        function clearSelection(): string {
            root.clearSelection()
            return "ok"
        }

        function selectedCount(): string {
            return String(root.selectedCount)
        }

        function selectedUris(): string {
            return JSON.stringify(root.getSelectedUris())
        }

        function add(path: string): string {
            var ok = root.addUrl(path)
            return ok ? "added" : "skipped"
        }
    }
}
