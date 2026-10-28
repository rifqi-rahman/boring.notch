//
//  AIUsageView.swift
//  boringNotch
//
//  The "AI" tab: one card per provider with a bar per usage window.
//

import SwiftUI

struct AIUsageView: View {
    @ObservedObject private var manager = AIUsageManager.shared

    var body: some View {
        HStack(spacing: 10) {
            if manager.usage.isEmpty {
                ToolTile {
                    if manager.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Turn on a provider in Settings → Tools")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(manager.usage) { usage in
                ProviderCard(usage: usage)
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await manager.userRefresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(manager.isRefreshing ? 360 : 0))
                    .animation(manager.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                               value: manager.isRefreshing)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(14)
        }
        .onAppear { manager.refreshIfStale() }
    }
}

private struct ProviderCard: View {
    let usage: ProviderUsage

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: usage.provider.symbol)
                    Text(usage.provider.name).fontWeight(.semibold)
                    if let plan = usage.plan {
                        Text(plan)
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13))

                if let error = usage.error {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(usage.windows.prefix(3)) { window in
                        WindowBar(window: window)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct WindowBar: View {
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(window.label)
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))%").monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * min(max(window.usedPercent / 100, 0), 1))
                }
            }
            .frame(height: 5)

            if let resets = window.resetsAt, resets > Date() {
                Text("Resets \(resets, style: .relative)")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var color: Color {
        switch window.usedPercent {
        case ..<60: .green
        case ..<85: .orange
        default: .red
        }
    }
}
