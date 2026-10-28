//
//  ClipboardView.swift
//  boringNotch
//
//  The "Clipboard" tab: search field plus a horizontal strip of history cards.
//

import Defaults
import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var manager = ClipboardHistoryManager.shared
    @Default(.clipboardPasteOnSelect) private var pasteOnSelect
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var entries: [ClipboardEntry] { manager.history.filtered(by: query) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search clipboard and text in images", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(Color.white.opacity(0.08)))
                .onTapGesture { setKeyForTextInput(true); searchFocused = true }

                Button(role: .destructive) { manager.clear() } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear unpinned items")
            }

            if entries.isEmpty {
                Text(query.isEmpty ? "Copy something and it shows up here" : "No matches")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(entries) { entry in
                            ClipboardCard(entry: entry, imageURL: manager.imageURL(for: entry))
                                .onTapGesture { select(entry) }
                                .contextMenu {
                                    Button(entry.pinned ? "Unpin" : "Pin") { manager.togglePin(entry) }
                                    if let ocr = entry.ocrText {
                                        Button("Copy Recognized Text") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(ocr, forType: .string)
                                        }
                                    }
                                    Divider()
                                    Button("Delete", role: .destructive) { manager.delete(entry) }
                                }
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            searchFocused = false
            setKeyForTextInput(false)
        }
    }

    private func select(_ entry: ClipboardEntry) {
        manager.copy(entry, paste: pasteOnSelect)
        setKeyForTextInput(false)
        if pasteOnSelect { vm.close() }
    }

    /// The notch panel only becomes key while a text field is in use.
    private func setKeyForTextInput(_ wants: Bool) {
        for window in NSApp.windows.compactMap({ $0 as? BoringNotchSkyLightWindow }) {
            window.wantsKeyForTextInput = wants
        }
    }
}

private struct ClipboardCard: View {
    let entry: ClipboardEntry
    let imageURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                if entry.pinned { Image(systemName: "pin.fill").foregroundStyle(.yellow) }
                Spacer(minLength: 0)
                Text(entry.date, style: .relative)
                    .lineLimit(1)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .frame(width: 150)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var content: some View {
        switch entry.kind {
        case .image:
            if let imageURL, let image = NSImage(contentsOf: imageURL) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        case .files:
            let names = entry.text.split(separator: "\n").map { ($0 as NSString).lastPathComponent }
            Text(names.joined(separator: "\n"))
                .font(.system(size: 11))
                .lineLimit(5)
        case .text, .link:
            Text(entry.text)
                .font(.system(size: 11))
                .foregroundStyle(entry.kind == .link ? Color.accentColor : .white)
                .lineLimit(6)
        }
    }

    private var symbol: String {
        switch entry.kind {
        case .text: "doc.plaintext"
        case .link: "link"
        case .image: entry.ocrText == nil ? "photo" : "text.viewfinder"
        case .files: "doc.on.doc"
        }
    }
}
