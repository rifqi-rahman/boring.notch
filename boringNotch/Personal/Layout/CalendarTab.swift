//
//  CalendarTab.swift
//  boringNotch
//
//  Calendar tab: the month/week calendar with the day's events, next to
//  the full to-do list.
//

import SwiftUI

struct CalendarTab: View {
    @EnvironmentObject private var vm: BoringViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CalendarView()
                .frame(width: 300)
                .environmentObject(vm)
                .onHover { vm.isHoveringCalendar = $0 }
            TodoListPanel()
        }
        .padding(.top, 2)
    }
}

/// Full to-do list with an add field, used by the Calendar tab.
struct TodoListPanel: View {
    @ObservedObject private var store = TodoStore.shared
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        ToolTile {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("To-Do", systemImage: "checklist")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if store.items.contains(where: \.done) {
                        Button("Clear done") { store.clearDone() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Add a task", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($focused)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .onTapGesture { setNotchKeyForTextInput(true); focused = true }
                    .onSubmit {
                        store.add(draft)
                        draft = ""
                    }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.sorted) { item in
                            Button { store.toggle(item) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.done ? Color.effectiveAccent : .secondary)
                                    Text(item.title)
                                        .strikethrough(item.done)
                                        .foregroundStyle(item.done ? .secondary : .primary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .font(.system(size: 12))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onDisappear {
            focused = false
            setNotchKeyForTextInput(false)
        }
    }
}
