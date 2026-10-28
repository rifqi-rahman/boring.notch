//
//  DashboardView.swift
//  boringNotch
//
//  Home tab: a compact bento. Left column now playing + shortcuts, middle
//  the week and today's events, right column AI usage + to-do. The gear
//  ("Edit") picks which cards show. Tapping a card opens its tab.
//

import AppKit
import Defaults
import SwiftUI

struct DashboardView: View {
    @Default(.homeWidgets) private var widgetIDs

    private func shows(_ widget: HomeWidget) -> Bool { widgetIDs.contains(widget.rawValue) }

    var body: some View {
        WithInNotchSettings {
            HStack(spacing: 8) {
                if shows(.music) || shows(.shortcuts) {
                    VStack(spacing: 8) {
                        if shows(.music) { NowPlayingCard() }
                        if shows(.shortcuts) { ShortcutsCard() }
                    }
                    .frame(width: 196)
                }
                if shows(.calendar) {
                    WeekCard().frame(width: 200)
                }
                if shows(.ai) || shows(.todo) {
                    VStack(spacing: 8) {
                        if shows(.ai) { AIUsageCard() }
                        if shows(.todo) { TodoCard() }
                    }
                }
            }
            .padding(.top, 2)
            .padding(.trailing, 28)
        } settings: {
            HomeEditView()
        }
    }
}

// MARK: - Cards

/// Bento card: rounded tile that opens a tab on tap.
private struct BentoCard<Content: View>: View {
    var destination: NotchViews?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                if let destination {
                    withAnimation(.smooth) { BoringViewCoordinator.shared.currentView = destination }
                }
            }
    }
}

private struct NowPlayingCard: View {
    @ObservedObject private var music = MusicManager.shared

    var body: some View {
        BentoCard(destination: .music) {
            HStack(spacing: 8) {
                Image(nsImage: music.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text(music.isPlayerIdle ? "Nothing playing" : music.songTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(music.artistName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 12) {
                        Button { music.previousTrack() } label: { Image(systemName: "backward.fill") }
                        Button { music.togglePlay() } label: { Image(systemName: music.isPlaying ? "pause.fill" : "play.fill") }
                        Button { music.nextTrack() } label: { Image(systemName: "forward.fill") }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.top, 2)
                }
            }
        }
    }
}

private struct ShortcutsCard: View {
    @ObservedObject private var caffeine = CaffeineManager.shared
    @ObservedObject private var mic = MicMuteManager.shared
    @ObservedObject private var pomodoro = PomodoroManager.shared

    var body: some View {
        HStack(spacing: 6) {
            shortcut("cup.and.saucer.fill", on: caffeine.isActive, tint: .orange, help: "Caffeine") {
                caffeine.isActive ? caffeine.deactivate()
                    : caffeine.activate(for: CaffeineManager.Duration(rawValue: Defaults[.caffeineDefaultDuration]) ?? .indefinite)
            }
            shortcut(mic.isMuted ? "mic.slash.fill" : "mic.fill", on: mic.isMuted, tint: .red, help: "Mute microphone") {
                mic.toggle()
            }
            shortcut("timer", on: pomodoro.isRunning, tint: .effectiveAccent, help: "Focus timer") {
                pomodoro.startOrPause()
            }
            shortcut("doc.on.clipboard", on: false, tint: .white, help: "Clipboard") {
                withAnimation(.smooth) { BoringViewCoordinator.shared.currentView = .clipboard }
            }
        }
        .frame(height: 34)
    }

    private func shortcut(_ icon: String, on: Bool, tint: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(on ? tint : Color.white.opacity(0.06)))
                .foregroundStyle(on ? Color.black : Color.white.opacity(0.85))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct WeekCard: View {
    @ObservedObject private var calendar = CalendarManager.shared

    private var weekDays: [Date] {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var upcoming: [EventModel] {
        calendar.events
            .filter { !$0.isAllDay && $0.end > .now }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        BentoCard(destination: nil) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        let isToday = Calendar.current.isDateInToday(day)
                        VStack(spacing: 2) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(isToday ? Color.effectiveAccent : .clear))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                if upcoming.isEmpty {
                    Text("No more events today")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                ForEach(upcoming.prefix(2), id: \.id) { event in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(nsColor: event.calendar.color))
                            .frame(width: 3, height: 24)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(event.title)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Text(event.start.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .task { await calendar.updateCurrentDate(.now) }
    }
}

private struct AIUsageCard: View {
    @ObservedObject private var ai = AIUsageManager.shared

    var body: some View {
        BentoCard(destination: .aiUsage) {
            VStack(alignment: .leading, spacing: 4) {
                if let usage = ai.activeUsage.first {
                    HStack(spacing: 4) {
                        Image(systemName: usage.provider.symbol)
                        Text(usage.provider.name)
                        if ai.inUse.contains(usage.provider) {
                            Circle().fill(.green).frame(width: 5, height: 5)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    ForEach(usage.windows.prefix(2)) { window in
                        HStack(spacing: 5) {
                            Text(window.label)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)
                            ProgressView(value: min(window.usedPercent / 100, 1))
                                .tint(window.usedPercent < 60 ? .green : window.usedPercent < 85 ? .orange : .red)
                            Text("\(Int(window.usedPercent))%")
                                .font(.system(size: 9))
                                .monospacedDigit()
                                .frame(width: 26, alignment: .trailing)
                        }
                    }
                } else {
                    Label("AI Usage", systemImage: "gauge.with.dots.needle.67percent")
                        .font(.system(size: 11, weight: .semibold))
                    Text(ai.isRefreshing ? "Loading…" : "No AI app in use")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { ai.refreshIfStale(maxAge: 120) }
    }
}

private struct TodoCard: View {
    @ObservedObject private var store = TodoStore.shared
    @State private var draft = ""
    @State private var adding = false
    @FocusState private var focused: Bool

    var body: some View {
        BentoCard(destination: nil) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("To-Do").font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Button {
                        adding = true
                        setNotchKeyForTextInput(true)
                        focused = true
                    } label: { Image(systemName: "plus") }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .bold))
                }
                if adding {
                    TextField("New task", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .focused($focused)
                        .onSubmit {
                            store.add(draft)
                            draft = ""
                            adding = false
                            setNotchKeyForTextInput(false)
                        }
                }
                ForEach(store.sorted.prefix(adding ? 1 : 2)) { item in
                    Button { store.toggle(item) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.done ? Color.effectiveAccent : .secondary)
                            Text(item.title)
                                .strikethrough(item.done)
                                .foregroundStyle(item.done ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
                if store.items.isEmpty && !adding {
                    Text("Nothing to do").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .onDisappear {
            adding = false
            setNotchKeyForTextInput(false)
        }
    }
}

// MARK: - Edit

private struct HomeEditView: View {
    @Default(.homeWidgets) private var widgetIDs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Show on Home")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(HomeWidget.allCases) { widget in
                    let on = widgetIDs.contains(widget.rawValue)
                    Button {
                        if on { widgetIDs.removeAll { $0 == widget.rawValue } } else { widgetIDs.append(widget.rawValue) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: widget.icon)
                            Text(widget.label)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 9)
                        .frame(height: 24)
                        .background(Capsule().fill(on ? Color.white.opacity(0.9) : Color.white.opacity(0.08)))
                        .foregroundStyle(on ? .black : .white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 6)
    }
}
