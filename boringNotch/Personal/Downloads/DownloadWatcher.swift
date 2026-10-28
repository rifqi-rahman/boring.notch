//
//  DownloadWatcher.swift
//  boringNotch
//
//  Watches ~/Downloads and reports files that finished downloading.
//

import AppKit
import Defaults

enum DownloadDetector {
    /// Extensions browsers use while a download is in progress.
    static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial", "opdownload", "tmp"]

    static func isPartial(_ name: String) -> Bool {
        partialExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// Names that appeared since `previous` and are complete files.
    static func finished(previous: Set<String>, current: Set<String>) -> [String] {
        current.subtracting(previous)
            .filter { !$0.hasPrefix(".") && !isPartial($0) }
            .sorted()
    }
}

@MainActor
final class DownloadWatcher: ObservableObject {
    static let shared = DownloadWatcher()

    /// The most recently finished download; cleared after a few seconds.
    @Published private(set) var lastFinished: URL?

    private let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?

    private init() {}

    func setEnabled(_ enabled: Bool) {
        source?.cancel()
        source = nil
        guard enabled else { return }
        known = listNames()
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.scheduleScan() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    func dismiss() {
        lastFinished = nil
    }

    func reveal() {
        if let url = lastFinished { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        dismiss()
    }

    /// Events arrive in bursts while a browser renames files, so debounce.
    private func scheduleScan() {
        scanTask?.cancel()
        scanTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            scan()
        }
    }

    private func scan() {
        let current = listNames()
        let finished = DownloadDetector.finished(previous: known, current: current)
        known = current
        guard let name = finished.last else { return }
        lastFinished = folder.appendingPathComponent(name)
        clearTask?.cancel()
        clearTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            lastFinished = nil
        }
    }

    private func listNames() -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
    }
}
