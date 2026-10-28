//
//  TabButton.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-24.
//

import SwiftUI

struct TabButton: View {
    let label: String
    let icon: String
    let selected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                if selected {
                    Text(label).font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, selected ? 12 : 10)
                .contentShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TabButton(label: "Home", icon: "tray.fill", selected: true) {
        Log.general.debug("Tapped")
    }
}
