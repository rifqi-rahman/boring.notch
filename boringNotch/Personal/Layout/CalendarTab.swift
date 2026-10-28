//
//  CalendarTab.swift
//  boringNotch
//
//  Calendar tab: the month/week calendar plus the selected day's events.
//

import SwiftUI

struct CalendarTab: View {
    @EnvironmentObject private var vm: BoringViewModel
    @ObservedObject private var calendar = CalendarManager.shared

    private var events: [EventModel] {
        calendar.events.sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CalendarView()
                .frame(width: 230)
                .onHover { vm.isHoveringCalendar = $0 }
            VStack(alignment: .leading, spacing: 6) {
                Text(calendar.currentWeekStartDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                if events.isEmpty {
                    Text("No events")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(events, id: \.id) { event in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color(nsColor: event.calendar.color))
                                    .frame(width: 3, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    Text(event.isAllDay ? "All day" : "\(event.start.formatted(date: .omitted, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let url = event.url { NSWorkspace.shared.open(url) }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }
}
