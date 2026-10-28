//
//  TodoStore.swift
//  boringNotch
//
//  A tiny to-do list for the Home bento, stored in UserDefaults as JSON.
//

import AppKit
import Defaults
import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var done = false
}

extension Defaults.Keys {
    static let todoItemsJSON = Key<String>("todoItemsJSON", default: "[]")
}

@MainActor
final class TodoStore: ObservableObject {
    static let shared = TodoStore()

    @Published private(set) var items: [TodoItem] = []

    private init() {
        items = (try? JSONDecoder().decode([TodoItem].self, from: Data(Defaults[.todoItemsJSON].utf8))) ?? []
    }

    /// Open items first, then done ones.
    var sorted: [TodoItem] { items.filter { !$0.done } + items.filter(\.done) }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TodoItem(title: trimmed), at: 0)
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].done.toggle()
        save()
    }

    func clearDone() {
        items.removeAll(where: \.done)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items), let json = String(data: data, encoding: .utf8) {
            Defaults[.todoItemsJSON] = json
        }
    }
}

/// The notch panel only becomes key while a text field is in use.
@MainActor
func setNotchKeyForTextInput(_ wants: Bool) {
    for window in NSApp.windows.compactMap({ $0 as? BoringNotchSkyLightWindow }) {
        window.wantsKeyForTextInput = wants
    }
}
