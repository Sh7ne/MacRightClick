import AppKit
import FinderSync

final class FinderSync: FIFinderSync {
    private var lastSelectedURLs: [URL] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else {
            return nil
        }

        let urls = selectedItemURLs()
        guard !urls.isEmpty else {
            return nil
        }
        lastSelectedURLs = urls

        let menu = NSMenu(title: "")

        let copyItem = NSMenuItem(
            title: "Copy Path",
            action: #selector(copySelectedPaths(_:)),
            keyEquivalent: ""
        )
        copyItem.target = self
        copyItem.image = MenuIcon.copyPath()
        menu.addItem(copyItem)

        if allPDFs(urls) {
            let convertItem = NSMenuItem(
                title: "Convert PDF to JPG",
                action: #selector(convertSelectedPDFs(_:)),
                keyEquivalent: ""
            )
            convertItem.target = self
            convertItem.image = MenuIcon.convertPDF()
            menu.addItem(convertItem)
        }

        if allAVIs(urls) {
            let convertItem = NSMenuItem(
                title: "Convert AVI to MP4",
                action: #selector(convertSelectedAVIs(_:)),
                keyEquivalent: ""
            )
            convertItem.target = self
            convertItem.image = MenuIcon.convertVideo()
            menu.addItem(convertItem)
        }

        return menu
    }

    @objc private func copySelectedPaths(_ sender: Any?) {
        let urls = currentSelectedURLs()
        guard !urls.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
        Logger.write("Copied \(urls.count) path(s).")
    }

    @objc private func convertSelectedPDFs(_ sender: Any?) {
        let pdfURLs = currentSelectedURLs()
        guard !pdfURLs.isEmpty, allPDFs(pdfURLs) else { return }

        guard let commandURL = convertCommandURL(for: pdfURLs) else {
            Logger.write("Could not create conversion command.")
            return
        }

        if !NSWorkspace.shared.open(commandURL) {
            Logger.write("Could not start PDF conversion.")
        }
    }

    @objc private func convertSelectedAVIs(_ sender: Any?) {
        let aviURLs = currentSelectedURLs()
        guard !aviURLs.isEmpty, allAVIs(aviURLs) else { return }

        guard let commandURL = convertCommandURL(for: aviURLs, host: "convert-avi") else {
            Logger.write("Could not create AVI conversion command.")
            return
        }

        if !NSWorkspace.shared.open(commandURL) {
            Logger.write("Could not start AVI conversion.")
        }
    }

    private func convertCommandURL(for urls: [URL], host: String = "convert") -> URL? {
        var components = URLComponents()
        components.scheme = "macrightclick"
        components.host = host
        components.queryItems = urls.map { URLQueryItem(name: "path", value: $0.path) }
        return components.url
    }

    private func selectedItemURLs() -> [URL] {
        let controller = FIFinderSyncController.default()
        let selectedURLs = controller.selectedItemURLs() ?? []
        if !selectedURLs.isEmpty {
            return selectedURLs
        }

        if let targetedURL = controller.targetedURL() {
            return [targetedURL]
        }

        return []
    }

    private func currentSelectedURLs() -> [URL] {
        let urls = selectedItemURLs()
        return urls.isEmpty ? lastSelectedURLs : urls
    }

    private func allPDFs(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
    }

    private func allAVIs(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { $0.pathExtension.lowercased() == "avi" }
    }

}

enum Logger {
    static func write(_ message: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacRightClick.log")
        let line = "\(Date()) FinderExtension: \(message)\n"

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
                try? handle.close()
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}

enum MenuIcon {
    static func copyPath() -> NSImage {
        make { rect, color in
            color.setStroke()

            let back = rect.insetBy(dx: 5, dy: 3).offsetBy(dx: -3, dy: 2)
            let front = rect.insetBy(dx: 5, dy: 3).offsetBy(dx: 2, dy: -2)
            roundedPage(in: back).stroke()
            roundedPage(in: front).stroke()
        }
    }

    static func convertPDF() -> NSImage {
        make { rect, color in
            color.setStroke()

            let page = rect.insetBy(dx: 5, dy: 3).offsetBy(dx: -2, dy: 1)
            roundedPage(in: page).stroke()

            let arrow = NSBezierPath()
            arrow.lineWidth = 1.8
            arrow.lineCapStyle = .round
            arrow.lineJoinStyle = .round
            arrow.move(to: NSPoint(x: rect.midX + 1, y: rect.midY - 3))
            arrow.line(to: NSPoint(x: rect.maxX - 3, y: rect.midY - 3))
            arrow.move(to: NSPoint(x: rect.maxX - 6, y: rect.midY))
            arrow.line(to: NSPoint(x: rect.maxX - 3, y: rect.midY - 3))
            arrow.line(to: NSPoint(x: rect.maxX - 6, y: rect.midY - 6))
            arrow.stroke()
        }
    }

    static func convertVideo() -> NSImage {
        make { rect, color in
            color.setStroke()

            let frame = rect.insetBy(dx: 3, dy: 5)
            let body = NSBezierPath(roundedRect: frame, xRadius: 2, yRadius: 2)
            body.lineWidth = 1.7
            body.stroke()

            let play = NSBezierPath()
            play.lineJoinStyle = .round
            play.move(to: NSPoint(x: rect.midX - 2, y: rect.midY + 4))
            play.line(to: NSPoint(x: rect.midX - 2, y: rect.midY - 4))
            play.line(to: NSPoint(x: rect.midX + 5, y: rect.midY))
            play.close()
            color.setFill()
            play.fill()
        }
    }

    private static func make(draw: (NSRect, NSColor) -> Void) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        draw(NSRect(origin: .zero, size: size), foregroundColor())
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private static func roundedPage(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
        path.lineWidth = 1.7
        return path
    }

    private static func foregroundColor() -> NSColor {
        if UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" {
            return .white
        }

        if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return .white
        }

        return NSColor(calibratedWhite: 0.12, alpha: 1)
    }
}
