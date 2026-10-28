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

    private enum Content { case call, music, timer, overview }

    private var content: Content {
        if call.callApp != nil, Defaults[.callIslandEnabled] { return .call }
        if music.isPlaying { return .music }
        if pomodoro.isActive { return .timer }
        if !music.isPlayerIdle { return .music }
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
        case .timer:
            TimerGlance().frame(width: 336)
        case .overview:
            OverviewGlance().frame(width: 360)
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

private struct TimerGlance: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: pomodoro.cycle.phase.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(color)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 0) {
                Text(pomodoro.cycle.phase.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(pomodoro.remainingText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            CircleAction(icon: pomodoro.isRunning ? "pause.fill" : "play.fill", tint: .white) {
                pomodoro.startOrPause()
            }
            CircleAction(icon: "forward.end.fill", tint: .white) { pomodoro.skip() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var color: Color { pomodoro.cycle.phase == .focus ? .effectiveAccent : .green }
}

private struct OverviewGlance: View {
    @ObservedObject private var ai = AIUsageManager.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(Date.now.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            if let usage = ai.usage.first(where: { $0.error == nil }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(usage.provider.name) \(Int(usage.peakPercent))%")
                        .font(.system(size: 11, weight: .medium))
                    ProgressView(value: min(usage.peakPercent / 100, 1))
                        .tint(usage.peakPercent < 60 ? .green : usage.peakPercent < 85 ? .orange : .red)
                        .frame(width: 90)
                }
            }
            Spacer()
            CircleAction(icon: "timer", tint: .white) { pomodoro.start() }
                .help("Start focus timer")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { ai.refreshIfStale(maxAge: 300) }
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
