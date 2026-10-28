//
//  ShelfExtrasService.swift
//  boringNotch
//
//  Extra Shelf actions for the personal build: unzip, PDF → images, OCR.
//

import AppKit
import PDFKit
import UniformTypeIdentifiers
import Vision

enum ShelfExtrasService {
    static func isArchive(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "zip"
    }

    static func isPDF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
    }

    /// Extracts a zip archive next to a temp folder using `ditto` and returns the extracted root items.
    static func extract(_ archive: URL) async -> [URL] {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("unzip_\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        } catch {
            return []
        }
        let ok = await runProcess("/usr/bin/ditto", ["-x", "-k", archive.path, dest.path])
        guard ok else { return [] }
        let items = (try? FileManager.default.contentsOfDirectory(
            at: dest, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return items.filter { $0.lastPathComponent != "__MACOSX" }
    }

    /// Renders every PDF page to a PNG in a temp folder.
    static func renderPages(of pdf: URL, scale: CGFloat = 2) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            guard let doc = PDFDocument(url: pdf) else { return [] }
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("pdfpages_\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let base = pdf.deletingPathExtension().lastPathComponent
            var out: [URL] = []
            for index in 0..<doc.pageCount {
                guard let page = doc.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let size = NSSize(width: bounds.width * scale, height: bounds.height * scale)
                let image = page.thumbnail(of: size, for: .mediaBox)
                guard let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else { continue }
                let url = dir.appendingPathComponent("\(base)-\(index + 1).png")
                if (try? png.write(to: url)) != nil { out.append(url) }
            }
            return out
        }.value
    }

    /// Recognizes text in an image file.
    static func recognizeText(in url: URL) async -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return await recognizeText(in: image)
    }

    static func recognizeText(in image: CGImage) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "id-ID"]
            let handler = VNImageRequestHandler(cgImage: image)
            do {
                try handler.perform([request])
            } catch {
                return nil
            }
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.isEmpty ? nil : lines.joined(separator: "\n")
        }.value
    }

    /// Adds produced files to the Shelf as temporary items.
    @MainActor
    static func addToShelf(_ urls: [URL]) {
        let items = urls.compactMap { url -> ShelfItem? in
            guard let bookmark = try? Bookmark(url: url) else { return nil }
            return ShelfItem(kind: .file(bookmark: bookmark.data), isTemporary: true)
        }
        if !items.isEmpty { ShelfStateViewModel.shared.add(items) }
    }

    private static func runProcess(_ path: String, _ args: [String]) async -> Bool {
        await withCheckedContinuation { cont in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: path)
            proc.arguments = args
            proc.terminationHandler = { cont.resume(returning: $0.terminationStatus == 0) }
            do {
                try proc.run()
            } catch {
                cont.resume(returning: false)
            }
        }
    }
}
