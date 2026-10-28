//
//  MediumNotchView.swift
//  boringNotch
//
//  The hover glance. Shows only what matters right now, in priority order:
//  an active call, playing music, a running timer, then a quick overview.
//  Clicking the notch expands to the large view.
//

import Defaults
import SwiftUI

struct MediumNotchView: View {
    @ObservedObject private var music = MusicManager.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared
    @ObservedObject private var call = CallIslandManager.shared
    let albumArtNamespace: Namespace.ID
    let horizontalMediaGestureFeedback: CGFloat

    private enum Content { case call, music, overview }

    /// A call or playing music takes over the glance; otherwise the overview.
    private var content: Content {
        if call.callApp != nil, Defaults[.callIslandEnabled] { return .call }
        if music.isPlaying { return .music }
        return .overview
    }

    var body: some View {
        switch content {
        case .call:
            CallGlance().frame(width: 336)
        case .music:
            CompactHomeView(albumArtNamespace: albumArtNamespace,
                            horizontalMediaGestureFeedback: horizontalMediaGestureFeedback)
                .frame(width: 336)
        case .overview:
            OverviewGlance().frame(width: 540)
        }
    }
}

private struct CallGlance: View {
    @ObservedObject private var call = CallIslandManager.shared
    @ObservedObject private var mic = MicMuteManager.shared

    var body: some View {
        HStack(spacing: 12) {
            if let icon = call.callApp?.icon {
                Image(nsImage: icon).resizable().frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(call.callApp?.localizedName ?? "Call")
                    .font(.system(size: 14, weight: .semibold))
                if let start = call.startedAt {
                    Text(start, style: .timer)
                        .font(.system(size: 12, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            CircleAction(icon: mic.isMuted ? "mic.slash.fill" : "mic.fill", tint: mic.isMuted ? .red : .white) {
                mic.toggle()
            }
            CircleAction(icon: "arrow.up.forward.app.fill", tint: .green) {
                call.bringAppForward()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Default hover glance: next events, to-do, and shortcuts.
private struct OverviewGlance: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var pomodoro = PomodoroManager.shared
    @ObservedObject private var caffeine = CaffeineManager.shared

    var body: some View {
        HStack(spacing: 8) {
            WeekCard().frame(width: 190)
            TodoCard().frame(width: 150)
            VStack(spacing: 6) {
                timerShortcut
                HStack(spacing: 6) {
                    GlanceButton(icon: "cup.and.saucer.fill", on: caffeine.isActive, tint: .orange, help: "Caffeine") {
                        caffeine.isActive ? caffeine.deactivate()
                            : caffeine.activate(for: CaffeineManager.Duration(rawValue: Defaults[.caffeineDefaultDuration]) ?? .indefinite)
                    }
                    GlanceButton(icon: "computermouse.fill", help: "Devices") { openTab(.tools) }
                }
                HStack(spacing: 6) {
                    GlanceButton(icon: "web.camera.fill", help: "Speaker & Camera") { openTab(.audio) }
                    GlanceButton(icon: "gearshape.fill", help: "Settings") {
                        SettingsWindowController.shared.showWindow()
                    }
                }
            }
        }
        .frame(height: 112)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// Start when idle; while active shows the countdown with pause, restart and stop.
    @ViewBuilder
    private var timerShortcut: some View {
        if pomodoro.isActive {
            HStack(spacing: 4) {
                Button { pomodoro.startOrPause() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: pomodoro.isRunning ? "pause.fill" : "play.fill")
                        Text(pomodoro.remainingText).monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.effectiveAccent))
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
                GlanceButton(icon: "arrow.counterclockwise", help: "Restart") {
                    pomodoro.reset()
                    pomodoro.start()
                }
                .frame(width: 30)
                GlanceButton(icon: "xmark", help: "Stop timer") { pomodoro.reset() }
                    .frame(width: 30)
            }
        } else {
            GlanceButton(icon: "timer", label: "Focus", help: "Start focus timer") { pomodoro.start() }
        }
    }

    private func openTab(_ view: NotchViews) {
        withAnimation(.smooth) {
            BoringViewCoordinator.shared.currentView = view
            vm.openSize = .large
        }
    }
}

private struct GlanceButton: View {
    let icon: String
    var label: String?
    var on = false
    var tint: Color = .white
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                if let label { Text(label) }
            }
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 9).fill(on ? tint : Color.white.opacity(0.07)))
            .foregroundStyle(on ? Color.black : Color.white.opacity(0.85))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct CircleAction: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }
}
