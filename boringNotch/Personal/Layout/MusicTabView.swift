//
//  MusicTabView.swift
//  boringNotch
//
//  Music tab: the player plus scrolling synced lyrics (no calendar; that
//  lives on Home now).
//

import Defaults
import SwiftUI

struct MusicTabView: View {
    @EnvironmentObject var vm: BoringViewModel
    let albumArtNamespace: Namespace.ID
    let horizontalMediaGestureFeedback: CGFloat
    @Binding var isHoveringMusicArea: Bool

    private var shouldShowCamera: Bool {
        Defaults[.showMirror] && vm.camera.cameraAvailable && vm.camera.isSessionRunning
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MusicPlayerView(
                albumArtNamespace: albumArtNamespace,
                horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                isHoveringMusicArea: $isHoveringMusicArea
            )
            if shouldShowCamera {
                CameraPreviewView(camera: vm.camera).scaledToFit()
            } else {
                LyricsPanel()
                    .frame(width: 230)
            }
        }
        .transition(.opacity)
    }
}

/// Previous, current and next lyric lines, following playback.
struct LyricsPanel: View {
    @ObservedObject private var lyrics = LyricsService.shared
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { context in
            let lines = visibleLines(at: music.estimatedPlaybackPosition(at: context.date))
            VStack(alignment: .leading, spacing: 6) {
                if lyrics.isFetchingLyrics {
                    Text("Loading lyrics…").foregroundStyle(.secondary)
                } else if lines.isEmpty {
                    Text(music.isPlayerIdle ? "Nothing playing" : "No lyrics for this song")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(size: line.isCurrent ? 15 : 12, weight: line.isCurrent ? .bold : .medium))
                            .foregroundStyle(line.isCurrent ? .white : .white.opacity(0.35))
                            .lineLimit(2)
                            .id(line.text + "\(index)")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .animation(.smooth(duration: 0.3), value: lines.map(\.text))
        }
        .padding(.vertical, 6)
    }

    private struct Line { let text: String; let isCurrent: Bool }

    private func visibleLines(at elapsed: Double) -> [Line] {
        let synced = lyrics.syncedLyrics
        guard !synced.isEmpty else {
            let plain = lyrics.currentLyrics.split(separator: "\n").prefix(4).map(String.init)
            return plain.map { Line(text: $0, isCurrent: false) }
        }
        let current = synced.lastIndex { $0.time <= elapsed } ?? 0
        let range = max(current - 1, 0)...min(current + 2, synced.count - 1)
        return range.compactMap { index in
            let text = synced[index].text.trimmingCharacters(in: .whitespaces)
            return text.isEmpty ? nil : Line(text: text, isCurrent: index == current)
        }
    }
}
