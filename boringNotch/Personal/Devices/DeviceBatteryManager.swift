//
//  DeviceBatteryManager.swift
//  boringNotch
//
//  Battery levels of connected Bluetooth devices (mouse, keyboard, AirPods…)
//  from IORegistry and system_profiler, plus a low-battery alert.
//

import Defaults
import Foundation

struct DeviceBattery: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let kind: String
    /// 0...100; for AirPods the lowest of the buds.
    let percent: Int

    var symbol: String {
        let lower = (kind + " " + name).lowercased()
        if lower.contains("mouse") { return "computermouse.fill" }
        if lower.contains("keyboard") { return "keyboard.fill" }
        if lower.contains("trackpad") { return "rectangle.and.hand.point.up.left.fill" }
        if lower.contains("airpods") || lower.contains("headphones") || lower.contains("headset") { return "airpods" }
        if lower.contains("watch") { return "applewatch" }
        return "battery.75percent"
    }
}

enum DeviceBatteryParser {
    /// Parses `system_profiler SPBluetoothDataType -json`.
    static func parseSystemProfiler(_ data: Data) -> [DeviceBattery] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let section = (root["SPBluetoothDataType"] as? [[String: Any]])?.first,
              let connected = section["device_connected"] as? [[String: Any]] else { return [] }
        return connected.flatMap { device in
            device.compactMap { name, value -> DeviceBattery? in
                guard let info = value as? [String: Any] else { return nil }
                let levels = ["device_batteryLevelMain", "device_batteryLevelLeft", "device_batteryLevelRight"]
                    .compactMap { (info[$0] as? String).flatMap(percent) }
                guard let level = levels.min() else { return nil }
                return DeviceBattery(name: name, kind: info["device_minorType"] as? String ?? "", percent: level)
            }
        }
    }

    /// Parses `ioreg -r -k BatteryPercent -a` (plist array of HID services).
    static func parseIORegistry(_ data: Data) -> [DeviceBattery] {
        guard let items = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item in
            guard let percent = (item["BatteryPercent"] as? NSNumber)?.intValue,
                  let name = item["Product"] as? String else { return nil }
            return DeviceBattery(name: name, kind: name, percent: percent)
        }
    }

    static func percent(_ string: String) -> Int? {
        Int(string.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
    }

    /// Merges sources, keeping one entry per device name.
    static func merge(_ lists: [[DeviceBattery]]) -> [DeviceBattery] {
        var seen = Set<String>()
        return lists.joined().filter { seen.insert($0.name).inserted }.sorted { $0.name < $1.name }
    }
}

@MainActor
final class DeviceBatteryManager: ObservableObject {
    static let shared = DeviceBatteryManager()

    @Published private(set) var devices: [DeviceBattery] = []
    /// Set when a device drops below the low threshold; cleared after a few seconds.
    @Published private(set) var lowDevice: DeviceBattery?

    private var timer: Timer?
    private var alerted = Set<String>()

    private init() {}

    func setEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else {
            devices = []
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in
            Task { @MainActor in await DeviceBatteryManager.shared.refresh() }
        }
        Task { await refresh() }
    }

    func refresh() async {
        let result = await Task.detached(priority: .utility) {
            let ioreg = Self.run("/usr/sbin/ioreg", ["-r", "-k", "BatteryPercent", "-a"]).map(DeviceBatteryParser.parseIORegistry) ?? []
            let profiler = Self.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"])
                .map(DeviceBatteryParser.parseSystemProfiler) ?? []
            return DeviceBatteryParser.merge([ioreg, profiler])
        }.value
        devices = result
        checkLow()
    }

    private func checkLow() {
        let threshold = Defaults[.deviceBatteryLowThreshold]
        for device in devices {
            if device.percent <= threshold {
                guard !alerted.contains(device.name) else { continue }
                alerted.insert(device.name)
                lowDevice = device
                Task {
                    try? await Task.sleep(for: .seconds(6))
                    if lowDevice == device { lowDevice = nil }
                }
            } else if device.percent > threshold + 5 {
                alerted.remove(device.name)
            }
        }
    }

    nonisolated private static func run(_ path: String, _ args: [String]) -> Data? {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return data
    }
}
