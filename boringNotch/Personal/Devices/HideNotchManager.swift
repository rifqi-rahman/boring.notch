//
//  HideNotchManager.swift
//  boringNotch
//
//  Hides the notch by setting a copy of the wallpaper with a black band
//  behind the menu bar on screens that have a notch. The original wallpaper
//  is remembered and restored when the feature is turned off.
//

import AppKit
import Defaults

@MainActor
final class HideNotchManager {
    static let shared = HideNotchManager()

    private var observers: [NSObjectProtocol] = []
    private let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("boringNotch/wallpapers", isDirectory: true)
    }()

    private init() {}

    func setEnabled(_ enabled: Bool) {
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers = []
        if enabled {
            applyAll()
            observers.append(NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
                    Task { @MainActor in HideNotchManager.shared.applyAll() }
                })
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
                    Task { @MainActor in HideNotchManager.shared.applyAll() }
                })
        } else {
            restoreAll()
        }
    }

    private func notchedScreens() -> [NSScreen] {
        NSScreen.screens.filter { $0.safeAreaInsets.top > 0 }
    }

    private func applyAll() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for screen in notchedScreens() { apply(to: screen) }
    }

    private func apply(to screen: NSScreen) {
        guard let key = screen.displayUUID,
              let current = NSWorkspace.shared.desktopImageURL(for: screen) else { return }
        // Already showing our banded copy.
        if current.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL { return }

        var originals = Defaults[.hideNotchOriginalWallpapers]
        originals[key] = current.path
        Defaults[.hideNotchOriginalWallpapers] = originals

        let band = max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
        guard let output = Self.renderBanded(source: current, screenSize: screen.frame.size,
                                             scale: screen.backingScaleFactor, bandHeight: band) else { return }
        // A new file name each time so macOS doesn't keep a cached image.
        let url = directory.appendingPathComponent("\(key)-\(UUID().uuidString.prefix(8)).png")
        guard (try? output.write(to: url)) != nil else { return }
        try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        cleanup(keeping: url, key: key)
    }

    private func restoreAll() {
        let originals = Defaults[.hideNotchOriginalWallpapers]
        for screen in NSScreen.screens {
            guard let key = screen.displayUUID, let path = originals[key] else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
        }
        Defaults[.hideNotchOriginalWallpapers] = [:]
        try? FileManager.default.removeItem(at: directory)
    }

    private func cleanup(keeping url: URL, key: String) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasPrefix(key) && file != url {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Draws the wallpaper aspect-filled to the screen with a black band on top.
    static func renderBanded(source: URL, screenSize: CGSize, scale: CGFloat, bandHeight: CGFloat) -> Data? {
        guard let image = NSImage(contentsOf: source) else { return nil }
        let pixelSize = CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(pixelSize.width), pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = screenSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let fill = max(screenSize.width / image.size.width, screenSize.height / image.size.height)
        let drawSize = CGSize(width: image.size.width * fill, height: image.size.height * fill)
        let origin = CGPoint(x: (screenSize.width - drawSize.width) / 2, y: (screenSize.height - drawSize.height) / 2)
        image.draw(in: CGRect(origin: origin, size: drawSize))
        NSColor.black.setFill()
        CGRect(x: 0, y: screenSize.height - bandHeight, width: screenSize.width, height: bandHeight).fill()
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }
}
