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

/// Tabs shown in the open notch. Shelf and Tools only appear when enabled.
var tabs: [TabModel] {
    var result = [TabModel(label: "Home", icon: "house.fill", view: .home)]
    if Defaults[.boringShelf] {
        result.append(TabModel(label: "Shelf", icon: "tray.fill", view: .shelf))
    }
    if Defaults[.showToolsTab] {
        result.append(TabModel(label: "Tools", icon: "square.grid.2x2.fill", view: .tools))
    }
    if Defaults[.clipboardHistoryEnabled] {
        result.append(TabModel(label: "Clipboard", icon: "doc.on.clipboard.fill", view: .clipboard))
    }
    if Defaults[.aiUsageEnabled] {
        result.append(TabModel(label: "AI", icon: "gauge.with.dots.needle.67percent", view: .aiUsage))
    }
    return result
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
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel(camera: CameraModel()))
}
