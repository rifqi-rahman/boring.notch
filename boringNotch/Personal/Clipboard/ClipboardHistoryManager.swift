//
//  ClipboardHistoryManager.swift
//  boringNotch
//
//  Watches NSPasteboard, records history to disk, runs OCR on images.
//

import AppKit
import CryptoKit
import Defaults

@MainActor
final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    @Published private(set) var history = ClipboardHistory()
    /// The entry just copied in another app; cleared after a moment.
    @Published private(set) var justCopied: ClipboardEntry?

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var saveTask: Task<Void, Never>?
    private var copiedTask: Task<Void, Never>?
    private var keyMonitor: Any?
    /// Last ⌘C / ⌘X. Some apps copy on selection; only a real copy
    /// keystroke shortly before the change shows the "Copied" alert.
    private var lastCopyKeystroke = Date.distantPast
    private static let maxTextLength = 100_000

    private let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("boringNotch/clipboard", isDirectory: true)
    }()
    private var imagesDirectory: URL { directory.appendingPathComponent("images", isDirectory: true) }
    private var historyFile: URL { directory.appendingPathComponent("history.json") }

    private init() {
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: historyFile),
           let saved = try? JSONDecoder().decode(ClipboardHistory.self, from: data) {
            history = saved
        }
    }

    func setEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        guard enabled else { return }
        // Global key monitors need Accessibility permission.
        if Defaults[.clipboardCopiedAlert] && !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let key = event.charactersIgnoringModifiers?.lowercased()
            guard event.modifierFlags.contains(.command), key == "c" || key == "x" else { return }
            Task { @MainActor in ClipboardHistoryManager.shared.lastCopyKeystroke = Date() }
        }
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in ClipboardHistoryManager.shared.poll() }
        }
        timer?.tolerance = 0.2
    }

    func imageURL(for entry: ClipboardEntry) -> URL? {
        entry.imageFile.map { imagesDirectory.appendingPathComponent($0) }
    }

    // MARK: Actions

    /// Puts the entry back on the pasteboard and optionally pastes it into the front app.
    func copy(_ entry: ClipboardEntry, paste: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch entry.kind {
        case .text, .link:
            pb.setString(entry.text, forType: .string)
        case .image:
            if let url = imageURL(for: entry), let image = NSImage(contentsOf: url) {
                pb.writeObjects([image])
            }
        case .files:
            let urls = entry.text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
            pb.writeObjects(urls as [NSURL])
        }
        // Our own write: move it to the top without the "Copied" alert.
        lastChangeCount = pb.changeCount
        deleteFiles(of: history.insert(entry, limit: Defaults[.clipboardHistoryLimit]))
        scheduleSave()
        if paste { Self.sendPasteKeystroke() }
    }

    func togglePin(_ entry: ClipboardEntry) {
        history.update(entry.id) { $0.pinned.toggle() }
        scheduleSave()
    }

    func delete(_ entry: ClipboardEntry) {
        if let removed = history.remove(entry.id) { deleteFiles(of: [removed]) }
        scheduleSave()
    }

    func clear() {
        deleteFiles(of: history.clearUnpinned())
        scheduleSave()
    }

    // MARK: Polling

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        let types = (pb.types ?? []).map(\.rawValue)
        guard !ClipboardHistory.shouldIgnore(types: types) else { return }
        let source = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            record(ClipboardEntry(kind: .files, text: urls.map(\.path).joined(separator: "\n"), sourceApp: source))
        } else if let string = pb.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let text = String(string.prefix(Self.maxTextLength))
            let isLink = URL(string: text).map { ["http", "https"].contains($0.scheme ?? "") } ?? false
                && !text.contains(where: \.isWhitespace)
            record(ClipboardEntry(kind: isLink ? .link : .text, text: text, sourceApp: source))
        } else if let image = NSImage(pasteboard: pb), let png = Self.pngData(image) {
            recordImage(png, source: source)
        }
    }

    private func recordImage(_ png: Data, source: String?) {
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        var entry = ClipboardEntry(kind: .image, text: "image:\(hash.prefix(32))", sourceApp: source)
        let existing = history.entries.first { $0.dedupeKey == entry.dedupeKey }
        if existing == nil {
            let name = "\(entry.id.uuidString).png"
            guard (try? png.write(to: imagesDirectory.appendingPathComponent(name))) != nil else { return }
            entry.imageFile = name
        }
        record(entry)

        guard existing?.ocrText == nil, Defaults[.clipboardOCREnabled],
              let stored = history.entries.first, let url = imageURL(for: stored) else { return }
        let id = stored.id
        Task {
            guard let text = await ShelfExtrasService.recognizeText(in: url) else { return }
            history.update(id) { $0.ocrText = text }
            scheduleSave()
        }
    }

    private func record(_ entry: ClipboardEntry) {
        deleteFiles(of: history.insert(entry, limit: Defaults[.clipboardHistoryLimit]))
        scheduleSave()
        guard Date().timeIntervalSince(lastCopyKeystroke) < 1.5 else { return }
        justCopied = history.entries.first
        copiedTask?.cancel()
        copiedTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            justCopied = nil
        }
    }

    // MARK: Persistence

    private func deleteFiles(of entries: [ClipboardEntry]) {
        for entry in entries {
            if let url = imageURL(for: entry) { try? FileManager.default.removeItem(at: url) }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = history
        let file = historyFile
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: file, options: .atomic)
        }
    }

    // MARK: Helpers

    private static func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// Simulates ⌘V into the frontmost app. Needs Accessibility permission.
    private static func sendPasteKeystroke() {
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKey: CGKeyCode = 9
            let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
            down?.flags = .maskCommand
            up?.flags = .maskCommand
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)
        }
    }
}
