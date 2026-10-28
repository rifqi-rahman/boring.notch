//
//  WindowSnapManager.swift
//  boringNotch
//
//  Drag a window up to the notch to reveal snap zones; drop on one to resize
//  the window through Accessibility.
//

import AppKit
import ApplicationServices
import Defaults
import SwiftUI

enum SnapZone: String, CaseIterable, Identifiable {
    case leftHalf, leftThird, maximize, rightThird, rightHalf

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .leftThird: "rectangle.leadingthird.inset.filled"
        case .maximize: "rectangle.fill"
        case .rightThird: "rectangle.trailingthird.inset.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        }
    }

    /// Target frame in AppKit coordinates (bottom-left origin).
    func frame(in visible: CGRect) -> CGRect {
        switch self {
        case .leftHalf: CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .rightHalf: CGRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .leftThird: CGRect(x: visible.minX, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .rightThird: CGRect(x: visible.maxX - visible.width / 3, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .maximize: visible
        }
    }

    /// Zone under `x` for a bar of `allCases.count` equal slots spanning `bar`.
    static func zone(atX x: CGFloat, in bar: ClosedRange<CGFloat>) -> SnapZone? {
        guard bar.contains(x), bar.upperBound > bar.lowerBound else { return nil }
        let slot = (x - bar.lowerBound) / (bar.upperBound - bar.lowerBound) * CGFloat(allCases.count)
        return allCases[min(Int(slot), allCases.count - 1)]
    }

    /// Converts an AppKit rect to Accessibility (top-left origin) coordinates.
    static func axRect(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}

@MainActor
final class WindowSnapManager: ObservableObject {
    static let shared = WindowSnapManager()

    @Published private(set) var hoveredZone: SnapZone?

    private var monitors: [Any] = []
    private var draggedWindow: AXUIElement?
    private var startPosition: CGPoint?
    private var overlay: NSPanel?
    private var overlayScreen: NSScreen?

    private static let barWidth: CGFloat = 320
    private static let barHeight: CGFloat = 54
    /// How close to the top edge the cursor must be to show the zones.
    private static let activationDepth: CGFloat = 60

    private init() {}

    func setEnabled(_ enabled: Bool) {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        hideOverlay()
        guard enabled else { return }
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        if let down = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { _ in
            Task { @MainActor in WindowSnapManager.shared.mouseDown() }
        }) { monitors.append(down) }
        if let drag = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { _ in
            Task { @MainActor in WindowSnapManager.shared.mouseDragged() }
        }) { monitors.append(drag) }
        if let up = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { _ in
            Task { @MainActor in WindowSnapManager.shared.mouseUp() }
        }) { monitors.append(up) }
    }

    // MARK: Events

    private func mouseDown() {
        draggedWindow = nil
        startPosition = nil
        guard AXIsProcessTrusted(), let window = Self.windowUnderCursor() else { return }
        draggedWindow = window
        startPosition = Self.position(of: window)
    }

    private func mouseDragged() {
        guard let window = draggedWindow, let start = startPosition,
              let now = Self.position(of: window), now != start else { return }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) else { return }

        if screen.frame.maxY - mouse.y <= Self.activationDepth || overlay != nil {
            showOverlay(on: screen)
            let bar = (screen.frame.midX - Self.barWidth / 2)...(screen.frame.midX + Self.barWidth / 2)
            let nearTop = screen.frame.maxY - mouse.y <= Self.activationDepth + Self.barHeight
            hoveredZone = nearTop ? SnapZone.zone(atX: mouse.x, in: bar) : nil
        }
    }

    private func mouseUp() {
        defer {
            draggedWindow = nil
            startPosition = nil
            hideOverlay()
        }
        guard let zone = hoveredZone, let window = draggedWindow, let screen = overlayScreen else { return }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let target = SnapZone.axRect(zone.frame(in: screen.visibleFrame), primaryHeight: primaryHeight)
        // The window manager may still be finishing the drag; apply after it settles.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Self.setFrame(target, of: window)
        }
    }

    // MARK: Overlay

    private func showOverlay(on screen: NSScreen) {
        if overlay != nil, overlayScreen == screen { return }
        hideOverlay()
        let top = screen.frame.maxY - max(screen.safeAreaInsets.top, 24) - 6
        let frame = CGRect(x: screen.frame.midX - Self.barWidth / 2, y: top - Self.barHeight,
                           width: Self.barWidth, height: Self.barHeight)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar + 1
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: SnapZonesView())
        panel.orderFrontRegardless()
        overlay = panel
        overlayScreen = screen
    }

    private func hideOverlay() {
        overlay?.orderOut(nil)
        overlay = nil
        overlayScreen = nil
        hoveredZone = nil
    }

    // MARK: Accessibility

    private static func windowUnderCursor() -> AXUIElement? {
        let mouse = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var element: AXUIElement?
        let system = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(system, Float(mouse.x), Float(primaryHeight - mouse.y), &element) == .success,
              var current = element else { return nil }
        for _ in 0..<12 {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &role)
            if role as? String == kAXWindowRole { return current }
            var parent: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parent) == .success,
                  let next = parent, CFGetTypeID(next) == AXUIElementGetTypeID() else { return nil }
            current = next as! AXUIElement
        }
        return nil
    }

    private static func position(of window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    private static func setFrame(_ rect: CGRect, of window: AXUIElement) {
        var origin = rect.origin
        var size = rect.size
        // Position, size, position: some apps clamp size against the old position.
        if let pos = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        }
        if let sz = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        }
        if let pos = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        }
    }
}

private struct SnapZonesView: View {
    @ObservedObject private var manager = WindowSnapManager.shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(SnapZone.allCases) { zone in
                Image(systemName: zone.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(manager.hoveredZone == zone ? Color.black : Color.white.opacity(0.8))
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(manager.hoveredZone == zone ? Color.white : Color.white.opacity(0.08)))
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 16).fill(.black))
        .animation(.easeOut(duration: 0.12), value: manager.hoveredZone)
    }
}
