//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import Defaults
import SwiftUI

struct TabModel: Identifiable {
    var id: String { label }
    let label: String
    let icon: String
    let view: NotchViews
}

/// Every tab the open notch can show, in display order. Home is always
/// first and can't be hidden; the rest follow their feature toggles and the
/// "…" customize page.
var allTabs: [TabModel] {
    var result = [
        TabModel(label: "Home", icon: "house.fill", view: .home),
        TabModel(label: "Music", icon: "music.note", view: .music),
        TabModel(label: "Timer", icon: "timer", view: .timer),
        TabModel(label: "Calendar", icon: "calendar", view: .calendar),
    ]
    if Defaults[.boringShelf] {
        result.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
    }
    if Defaults[.clipboardHistoryEnabled] {
        result.append(TabModel(label: "Clipboard", icon: "doc.on.clipboard.fill", view: .clipboard))
    }
    if Defaults[.aiUsageEnabled] {
        result.append(TabModel(label: "AI", icon: "gauge.with.dots.needle.67percent", view: .aiUsage))
    }
    if Defaults[.showToolsTab] {
        result.append(TabModel(label: "System", icon: "cpu", view: .tools))
        result.append(TabModel(label: "Speaker & Camera", icon: "web.camera.fill", view: .audio))
    }
    return result
}

/// The camera housing covers the middle of the header, so tabs are split:
/// the first few sit left of the notch, the rest right of it.
let maxLeftTabs = 7

/// Tabs shown in the tab bar.
var tabs: [TabModel] {
    let hidden = Set(Defaults[.hiddenTabs])
    return allTabs.filter { $0.view == .home || !hidden.contains($0.label) }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation
    /// nil = the tabs left of the notch.
    var side: Side = .left

    enum Side { case left, right }

    private var shownTabs: [TabModel] {
        side == .left ? Array(tabs.prefix(maxLeftTabs)) : Array(tabs.dropFirst(maxLeftTabs))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(shownTabs) { tab in
                tabButton(label: tab.label, icon: tab.icon, view: tab.view)
            }
            if side == .right {
                tabButton(label: "Customize", icon: "ellipsis", view: .customize)
            }
        }
        .clipShape(Capsule())
    }

    private func tabButton(label: String, icon: String, view: NotchViews) -> some View {
        let selected = coordinator.currentView == view
        return TabButton(label: label, icon: icon, selected: selected) {
            withAnimation(.smooth) {
                coordinator.currentView = (view == .customize && selected) ? .home : view
            }
        }
        .frame(height: 26)
        .foregroundStyle(selected ? .white : .gray)
        .background {
            Capsule()
                .fill(selected ? Color(nsColor: .secondarySystemFill) : Color.clear)
                .matchedGeometryEffect(id: "capsule", in: animation, isSource: selected)
                .opacity(selected ? 1 : 0)
        }
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel(camera: CameraModel()))
}
