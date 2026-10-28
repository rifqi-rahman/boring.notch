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
        result.append(TabModel(label: "Tools", icon: "square.grid.2x2.fill", view: .tools))
    }
    return result
}

/// Tabs shown in the tab bar.
var tabs: [TabModel] {
    let hidden = Set(Defaults[.hiddenTabs])
    return allTabs.filter { $0.view == .home || !hidden.contains($0.label) }
}

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Namespace var animation
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                    TabButton(label: tab.label, icon: tab.icon, selected: coordinator.currentView == tab.view) {
                        withAnimation(.smooth) {
                            coordinator.currentView = tab.view
                        }
                    }
                    .frame(height: 26)
                    .foregroundStyle(tab.view == coordinator.currentView ? .white : .gray)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        } else {
                            Capsule()
                                .fill(coordinator.currentView == tab.view ? Color(nsColor: .secondarySystemFill) : Color.clear)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                                .hidden()
                        }
                    }
            }
            TabButton(label: "Customize", icon: "ellipsis", selected: coordinator.currentView == .customize) {
                withAnimation(.smooth) {
                    coordinator.currentView = coordinator.currentView == .customize ? .home : .customize
                }
            }
            .frame(height: 26)
            .foregroundStyle(coordinator.currentView == .customize ? .white : .gray)
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel(camera: CameraModel()))
}
