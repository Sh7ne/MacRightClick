import AppKit
import AVFoundation
import ImageIO
import PDFKit
import SwiftUI

@main
struct MacRightClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Mac RightClick is installed.")
                .padding()
                .frame(width: 280)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didReceiveInput = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let argumentURLs = CommandLine.arguments.dropFirst().map { URL(fileURLWithPath: $0) }
        AppLogger.write("Launched with arguments: \(CommandLine.arguments.dropFirst().joined(separator: " | "))")
        guard !argumentURLs.isEmpty else {
            AppLogger.write("No file arguments received.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if !self.didReceiveInput {
                    AppLogger.write("No input arrived; terminating idle app.")
                    NSApp.terminate(nil)
                }
            }
            return
        }
        convert(urls: argumentURLs)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        AppLogger.write("Opened URLs: \(urls.map(\.absoluteString).joined(separator: " | "))")
        var pdfURLs: [URL] = []
        var aviURLs: [URL] = []
        var fileURLs: [URL] = []

        for url in urls {
            if let command = commandURLs(from: url) {
                switch command.kind {
                case .pdf:
                    pdfURLs.append(contentsOf: command.urls)
                case .avi:
                    aviURLs.append(contentsOf: command.urls)
                }
            } else {
                fileURLs.append(url)
            }
        }

        if pdfURLs.isEmpty, aviURLs.isEmpty {
            convert(urls: fileURLs)
        } else {
            convert(pdfURLs: pdfURLs, aviURLs: aviURLs)
        }
    }

    private func convert(urls: [URL]) {
        convert(
            pdfURLs: urls.filter { $0.pathExtension.lowercased() == "pdf" },
            aviURLs: urls.filter { $0.pathExtension.lowercased() == "avi" }
        )
    }

    private func convert(pdfURLs: [URL], aviURLs: [URL]) {
        didReceiveInput = true
        AppLogger.write("PDF URLs: \(pdfURLs.map(\.path).joined(separator: " | "))")
        AppLogger.write("AVI URLs: \(aviURLs.map(\.path).joined(separator: " | "))")

        do {
            for url in pdfURLs {
                AppLogger.write("Converting: \(url.path)")
                try PDFJPGConverter.convert(pdfURL: url)
            }

            if !pdfURLs.isEmpty {
                AppLogger.write("Converted \(pdfURLs.count) PDF file(s).")
            }

            for url in aviURLs {
                AppLogger.write("Converting AVI: \(url.path)")
                let outputURL = try AVIMP4Converter.convert(aviURL: url)
                AppLogger.write("Created MP4: \(outputURL.path)")
            }

            if !aviURLs.isEmpty {
                AppLogger.write("Converted \(aviURLs.count) AVI file(s).")
            }

            if pdfURLs.isEmpty, aviURLs.isEmpty {
                AppLogger.write("No supported files found in input.")
            }
        } catch {
            let message = userFacingMessage(for: error)
            AppLogger.write("Conversion failed: \(message)")
        }

        NSApp.terminate(nil)
    }

    private func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == NSPOSIXErrorDomain {
            if nsError.code == NSFileWriteNoPermissionError ||
                nsError.code == NSFileReadNoPermissionError ||
                nsError.code == Int(EACCES) ||
                nsError.code == Int(EPERM) {
                return "Permission denied. Allow Mac RightClick in System Settings > Privacy & Security > Files and Folders."
            }
        }

        return error.localizedDescription
    }

    private func commandURLs(from url: URL) -> (kind: CommandKind, urls: [URL])? {
        guard url.scheme == "macrightclick" else {
            return nil
        }

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let kind = CommandKind(host: components.host)
        else {
            AppLogger.write("Ignored command URL: \(url.absoluteString)")
            return nil
        }

        let paths = components.queryItems?
            .filter { $0.name == "path" }
            .compactMap(\.value) ?? []
        AppLogger.write("Command URL paths: \(paths.joined(separator: " | "))")
        return (kind, paths.map { URL(fileURLWithPath: $0) })
    }
}

private enum CommandKind {
    case pdf
    case avi

    init?(host: String?) {
        switch host {
        case "convert", "convert-pdf":
            self = .pdf
        case "convert-avi":
            self = .avi
        default:
            return nil
        }
    }
}

enum AppLogger {
    static func write(_ message: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/MacRightClick.log")
        let line = "\(Date()) App: \(message)\n"

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

enum PDFJPGConverter {
    static func convert(pdfURL: URL) throws {
        let didAccess = pdfURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: pdfURL), document.pageCount > 0 else {
            throw ConversionError.unreadablePDF(pdfURL.lastPathComponent)
        }

        if document.pageCount == 1 {
            let outputURL = uniqueFileURL(
                in: pdfURL.deletingLastPathComponent(),
                stem: pdfURL.deletingPathExtension().lastPathComponent,
                extensionName: "jpg"
            )
            try render(page: document.page(at: 0), to: outputURL)
        } else {
            let folderURL = uniqueFolderURL(
                in: pdfURL.deletingLastPathComponent(),
                name: "\(pdfURL.deletingPathExtension().lastPathComponent) JPG"
            )
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            for index in 0..<document.pageCount {
                guard let page = document.page(at: index) else { continue }
                let outputURL = folderURL.appendingPathComponent(
                    "\(pdfURL.deletingPathExtension().lastPathComponent)-\(index + 1).jpg"
                )
                try render(page: page, to: outputURL)
            }
        }
    }

    private static func render(page: PDFPage?, to outputURL: URL) throws {
        guard let page else {
            throw ConversionError.unreadablePage
        }

        let pageBounds = page.bounds(for: .mediaBox)
        let scale = 200.0 / 72.0
        let pixelWidth = max(1, Int((pageBounds.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((pageBounds.height * scale).rounded(.up)))
        let image = NSImage(size: NSSize(width: pixelWidth, height: pixelHeight))

        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw ConversionError.renderFailed
        }

        NSColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.saveGState()
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let jpg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.95])
        else {
            throw ConversionError.renderFailed
        }

        try jpg.write(to: outputURL)
    }

    private static func uniqueFileURL(in folder: URL, stem: String, extensionName: String) -> URL {
        FileNamer.uniqueFileURL(in: folder, stem: stem, extensionName: extensionName)
    }

    private static func uniqueFolderURL(in folder: URL, name: String) -> URL {
        var candidate = folder.appendingPathComponent(name, isDirectory: true)
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) \(index)", isDirectory: true)
            index += 1
        }

        return candidate
    }
}

enum AVIMP4Converter {
    static func convert(aviURL: URL) throws -> URL {
        let didAccess = aviURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                aviURL.stopAccessingSecurityScopedResource()
            }
        }

        let asset = AVURLAsset(url: aviURL)
        let outputURL = FileNamer.uniqueFileURL(
            in: aviURL.deletingLastPathComponent(),
            stem: aviURL.deletingPathExtension().lastPathComponent,
            extensionName: "mp4"
        )

        do {
            try exportWithAVFoundation(asset: asset, inputName: aviURL.lastPathComponent, outputURL: outputURL)
            return outputURL
        } catch {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }

            try MJPEGAVIConverter.convert(aviURL: aviURL, outputURL: outputURL)
            return outputURL
        }
    }

    private static func exportWithAVFoundation(asset: AVURLAsset, inputName: String, outputURL: URL) throws {
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        let candidatePresets = [
            AVAssetExportPresetPassthrough,
            AVAssetExportPresetHighestQuality,
            AVAssetExportPreset1920x1080,
            AVAssetExportPreset1280x720
        ].filter { compatiblePresets.contains($0) }

        let exportSession = candidatePresets
            .compactMap { AVAssetExportSession(asset: asset, presetName: $0) }
            .first { $0.supportedFileTypes.contains(.mp4) }

        guard let exportSession else {
            throw ConversionError.mp4Unsupported(inputName)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        let semaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously {
            semaphore.signal()
        }
        semaphore.wait()

        switch exportSession.status {
        case .completed:
            return
        default:
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            throw ConversionError.videoExportFailed(
                exportSession.error?.localizedDescription ?? "Unknown AVFoundation export error."
            )
        }
    }
}

enum MJPEGAVIConverter {
    static func convert(aviURL: URL, outputURL: URL) throws {
        let avi = try AVIFile(url: aviURL)
        guard avi.isMotionJPEG, !avi.frames.isEmpty else {
            throw ConversionError.unsupportedAVI(aviURL.lastPathComponent)
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: avi.width,
            AVVideoHeightKey: avi.height
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: avi.width,
            kCVPixelBufferHeightKey as String: avi.height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: attributes
        )

        guard writer.canAdd(input) else {
            throw ConversionError.videoExportUnavailable(aviURL.lastPathComponent)
        }

        writer.add(input)
        guard writer.startWriting() else {
            throw ConversionError.videoExportFailed(writer.error?.localizedDescription ?? "Could not start MP4 writer.")
        }

        writer.startSession(atSourceTime: .zero)
        let frameDuration = CMTime(seconds: 1.0 / avi.framesPerSecond, preferredTimescale: 600)

        for (index, frame) in avi.frames.enumerated() {
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }

            guard let buffer = makePixelBuffer(fromJPEG: frame, width: avi.width, height: avi.height, adaptor: adaptor) else {
                throw ConversionError.videoExportFailed("Could not decode a Motion JPEG frame.")
            }

            let time = CMTimeMultiply(frameDuration, multiplier: Int32(index))
            if !adaptor.append(buffer, withPresentationTime: time) {
                throw ConversionError.videoExportFailed(writer.error?.localizedDescription ?? "Could not append a video frame.")
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }
            throw ConversionError.videoExportFailed(writer.error?.localizedDescription ?? "Could not finish MP4 writer.")
        }
    }

    private static func makePixelBuffer(
        fromJPEG data: Data,
        width: Int,
        height: Int,
        adaptor: AVAssetWriterInputPixelBufferAdaptor
    ) -> CVPixelBuffer? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        var pixelBuffer: CVPixelBuffer?
        if let pool = adaptor.pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        } else {
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        }

        guard let pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard
            let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer),
            let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )
        else {
            return nil
        }

        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}

struct AVIFile {
    let width: Int
    let height: Int
    let framesPerSecond: Double
    let isMotionJPEG: Bool
    let frames: [Data]

    init(url: URL) throws {
        let data = try Data(contentsOf: url)
        guard
            data.ascii(at: 0, count: 4) == "RIFF",
            data.ascii(at: 8, count: 4) == "AVI "
        else {
            throw ConversionError.unsupportedAVI(url.lastPathComponent)
        }

        var parser = AVIParser(data: data)
        parser.parseRange(12..<data.count, inMovieList: false)

        guard parser.width > 0, parser.height > 0 else {
            throw ConversionError.unsupportedAVI(url.lastPathComponent)
        }

        width = parser.width
        height = parser.height
        framesPerSecond = parser.framesPerSecond
        isMotionJPEG = parser.isMotionJPEG
        frames = parser.frames
    }
}

private struct AVIParser {
    let data: Data
    var width = 0
    var height = 0
    var microsecondsPerFrame = 0
    var streamScale = 0
    var streamRate = 0
    var videoCompression = ""
    var frames: [Data] = []

    var isMotionJPEG: Bool {
        let codec = videoCompression.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return codec == "MJPG" || codec == "MJPEG"
    }

    var framesPerSecond: Double {
        if streamScale > 0, streamRate > 0 {
            return max(1.0, Double(streamRate) / Double(streamScale))
        }

        if microsecondsPerFrame > 0 {
            return max(1.0, 1_000_000.0 / Double(microsecondsPerFrame))
        }

        return 30
    }

    mutating func parseRange(_ range: Range<Int>, inMovieList: Bool) {
        var offset = range.lowerBound
        while offset + 8 <= range.upperBound {
            let id = data.ascii(at: offset, count: 4)
            let size = Int(data.uint32(at: offset + 4))
            let payloadStart = offset + 8
            let payloadEnd = min(payloadStart + size, range.upperBound)
            guard payloadStart <= payloadEnd else { return }

            if id == "LIST", payloadStart + 4 <= payloadEnd {
                let listType = data.ascii(at: payloadStart, count: 4)
                parseRange((payloadStart + 4)..<payloadEnd, inMovieList: inMovieList || listType == "movi")
            } else if inMovieList, isVideoFrameChunk(id), let frame = jpegFrame(in: payloadStart..<payloadEnd) {
                frames.append(frame)
            } else {
                parseHeaderChunk(id: id, range: payloadStart..<payloadEnd)
            }

            offset = payloadStart + size + (size % 2)
        }
    }

    private mutating func parseHeaderChunk(id: String, range: Range<Int>) {
        switch id {
        case "avih":
            if range.lowerBound + 4 <= range.upperBound {
                microsecondsPerFrame = Int(data.uint32(at: range.lowerBound))
            }
        case "strh":
            guard
                range.lowerBound + 28 <= range.upperBound,
                data.ascii(at: range.lowerBound, count: 4) == "vids"
            else { return }
            videoCompression = data.ascii(at: range.lowerBound + 4, count: 4)
            streamScale = Int(data.uint32(at: range.lowerBound + 20))
            streamRate = Int(data.uint32(at: range.lowerBound + 24))
        case "strf":
            guard range.lowerBound + 20 <= range.upperBound else { return }
            let parsedWidth = Int(Int32(bitPattern: data.uint32(at: range.lowerBound + 4)))
            let parsedHeight = abs(Int(Int32(bitPattern: data.uint32(at: range.lowerBound + 8))))
            if parsedWidth > 0, parsedHeight > 0 {
                width = parsedWidth
                height = parsedHeight
            }
            videoCompression = data.ascii(at: range.lowerBound + 16, count: 4)
        default:
            break
        }
    }

    private func isVideoFrameChunk(_ id: String) -> Bool {
        id.count == 4 && (id.hasSuffix("dc") || id.hasSuffix("db"))
    }

    private func jpegFrame(in range: Range<Int>) -> Data? {
        guard
            let start = data.firstIndex(of: 0xff, in: range),
            start + 1 < range.upperBound,
            data[start + 1] == 0xd8,
            let end = data.jpegEndIndex(in: start..<range.upperBound)
        else {
            return nil
        }

        return data.subdata(in: start..<end)
    }
}

private extension Data {
    func uint32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func ascii(at offset: Int, count: Int) -> String {
        guard offset + count <= self.count else { return "" }
        return String(decoding: self[offset..<offset + count], as: UTF8.self)
    }

    func firstIndex(of byte: UInt8, in range: Range<Int>) -> Int? {
        var index = range.lowerBound
        while index < range.upperBound {
            if self[index] == byte {
                return index
            }
            index += 1
        }
        return nil
    }

    func jpegEndIndex(in range: Range<Int>) -> Int? {
        var index = range.lowerBound + 2
        while index + 1 < range.upperBound {
            if self[index] == 0xff, self[index + 1] == 0xd9 {
                return index + 2
            }
            index += 1
        }
        return nil
    }
}

enum FileNamer {
    static func uniqueFileURL(in folder: URL, stem: String, extensionName: String) -> URL {
        var candidate = folder.appendingPathComponent(stem).appendingPathExtension(extensionName)
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(stem) \(index)").appendingPathExtension(extensionName)
            index += 1
        }

        return candidate
    }
}

enum ConversionError: LocalizedError {
    case unreadablePDF(String)
    case unreadablePage
    case renderFailed
    case videoExportUnavailable(String)
    case mp4Unsupported(String)
    case videoExportFailed(String)
    case unsupportedAVI(String)

    var errorDescription: String? {
        switch self {
        case .unreadablePDF(let name):
            return "Could not read PDF: \(name)"
        case .unreadablePage:
            return "Could not read a PDF page."
        case .renderFailed:
            return "Could not render PDF page to JPG."
        case .videoExportUnavailable(let name):
            return "Could not export AVI with AVFoundation: \(name)"
        case .mp4Unsupported(let name):
            return "AVFoundation cannot write MP4 for this AVI: \(name)"
        case .videoExportFailed(let message):
            return "Could not convert AVI to MP4: \(message)"
        case .unsupportedAVI(let name):
            return "This AVI is not a Motion JPEG file AVFoundation can convert: \(name)"
        }
    }
}
