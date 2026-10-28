//
//  ToolsLiveActivities.swift
//  boringNotch
//
//  Closed-notch live activities for the Tools features: privacy indicator
//  (camera / mic in use), mic muted, and the Pomodoro countdown.
//

import Combine
import Defaults
import SwiftUI

/// Which tool activities should be in the closed-notch stack.
///
/// ContentView observes this instead of the managers directly: the Pomodoro
/// manager publishes every half second, and re-rendering the whole notch
/// that often just to keep a boolean current would be wasteful.
@MainActor
final class ToolsActivityState: ObservableObject {
    static let shared = ToolsActivityState()

    @Published private(set) var pomodoroActive = false
    @Published private(set) var micMuted = false
    @Published private(set) var cameraInUse = false
    @Published private(set) var micInUse = false
    @Published private(set) var downloadFinished = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        PomodoroManager.shared.$isActive.removeDuplicates()
            .sink { [weak self] in self?.pomodoroActive = $0 }.store(in: &cancellables)
        MicMuteManager.shared.$isMuted.removeDuplicates()
            .sink { [weak self] in self?.micMuted = $0 }.store(in: &cancellables)
        CameraGuardManager.shared.$cameraInUse.removeDuplicates()
            .sink { [weak self] in self?.cameraInUse = $0 }.store(in: &cancellables)
        CameraGuardManager.shared.$micInUse.removeDuplicates()
            .sink { [weak self] in self?.micInUse = $0 }.store(in: &cancellables)
        DownloadWatcher.shared.$lastFinished.map { $0 != nil }.removeDuplicates()
            .sink { [weak self] in self?.downloadFinished = $0 }.store(in: &cancellables)
        Defaults.publisher(keys: .cameraGuardEnabled, .micGuardEnabled, .showMicMutedActivity, .showPomodoroActivity, .downloadAlertsEnabled)
            .sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    /// Tool activities in display priority order.
    var items: [LiveActivityItem] {
        var items: [LiveActivityItem] = []
        let camera = cameraInUse && Defaults[.cameraGuardEnabled]
        // A muted mic that is "running" is not a privacy concern.
        let mic = micInUse && !micMuted && Defaults[.micGuardEnabled]
        if downloadFinished && Defaults[.downloadAlertsEnabled] {
            items.append(.downloadFinished)
        }
        if camera || mic {
            items.append(.privacy(camera: camera, mic: mic))
        }
        if micMuted && Defaults[.showMicMutedActivity] {
            items.append(.micMuted)
        }
        if pomodoroActive && Defaults[.showPomodoroActivity] {
            items.append(.pomodoro)
        }
        return items
    }
}

extension LiveActivityItem {
    /// Width of each side wing around the physical notch for tool activities.
    var toolSideWidth: CGFloat? {
        switch self {
        case .privacy(let camera, let mic): (camera && mic) ? 44 : 26
        case .micMuted: 26
        case .pomodoro: 52
        case .downloadFinished: 30
        default: nil
        }
    }
}

/// Icon on the left wing, accessory on the right, notch-sized gap between.
struct ToolLiveActivity<Leading: View, Trailing: View>: View {
    @EnvironmentObject private var vm: BoringViewModel
    let sideWidth: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: sideWidth, alignment: .center)
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - cornerRadiusInsets.closed.top + 8)
            trailing
                .frame(width: sideWidth, alignment: .center)
        }
        .frame(height: vm.effectiveClosedNotchHeight)
    }
}

struct PrivacyLiveActivity: View {
    let camera: Bool
    let mic: Bool
    let sideWidth: CGFloat

    var body: some View {
        ToolLiveActivity(sideWidth: sideWidth) {
            HStack(spacing: 4) {
                if camera {
                    Image(systemName: "video.fill").foregroundStyle(.green)
                }
                if mic {
                    Image(systemName: "mic.fill").foregroundStyle(.orange)
                }
            }
            .font(.system(size: 11, weight: .semibold))
        } trailing: {
            Circle()
                .fill(camera ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
        }
    }
}

struct MicMutedLiveActivity: View {
    let sideWidth: CGFloat

    var body: some View {
        ToolLiveActivity(sideWidth: sideWidth) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.red)
        } trailing: {
            Button {
                MicMuteManager.shared.setMuted(false)
            } label: {
                Text("Off")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

struct PomodoroLiveActivity: View {
    @ObservedObject private var pomodoro = PomodoroManager.shared
    let sideWidth: CGFloat

    var body: some View {
        ToolLiveActivity(sideWidth: sideWidth) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: pomodoro.progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 15, height: 15)
        } trailing: {
            Text(pomodoro.remainingText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(pomodoro.isRunning ? color : .gray)
        }
    }

    private var color: Color {
        pomodoro.cycle.phase == .focus ? .effectiveAccent : .green
    }
}

struct DownloadLiveActivity: View {
    @ObservedObject private var watcher = DownloadWatcher.shared
    let sideWidth: CGFloat

    var body: some View {
        ToolLiveActivity(sideWidth: sideWidth) {
            if let url = watcher.lastFinished {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 18, height: 18)
            }
        } trailing: {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        }
        .contentShape(Rectangle())
        .onTapGesture { watcher.reveal() }
        .help(watcher.lastFinished?.lastPathComponent ?? "")
    }
}
