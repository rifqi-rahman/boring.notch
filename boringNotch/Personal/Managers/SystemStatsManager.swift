//
//  SystemStatsManager.swift
//  boringNotch
//
//  CPU and memory usage for the Tools tab. Sampling only runs while some
//  view holds a subscription (the notch is open on the Tools tab), so it
//  costs nothing in the background.
//

import Combine
import Darwin
import Foundation

struct SystemStats: Equatable {
    /// 0...1 across all cores.
    var cpu: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = ProcessInfo.processInfo.physicalMemory

    var memoryFraction: Double {
        memoryTotal == 0 ? 0 : Double(memoryUsed) / Double(memoryTotal)
    }
}

/// CPU tick counters summed over every core.
struct CPUTicks: Equatable {
    var user: UInt64 = 0
    var system: UInt64 = 0
    var idle: UInt64 = 0
    var nice: UInt64 = 0

    var busy: UInt64 { user + system + nice }
    var total: UInt64 { busy + idle }

    /// Fraction of time busy between two samples; 0 when nothing elapsed.
    static func usage(from old: CPUTicks, to new: CPUTicks) -> Double {
        guard new.total > old.total else { return 0 }
        let busy = Double(new.busy &- old.busy)
        let total = Double(new.total - old.total)
        return min(max(busy / total, 0), 1)
    }
}

@MainActor
final class SystemStatsManager: ObservableObject {
    static let shared = SystemStatsManager()

    @Published private(set) var stats = SystemStats()

    private var subscribers = 0
    private var timer: Timer?
    private var previousTicks: CPUTicks?

    private init() {}

    /// Call from `onAppear`; balance with `stop()` in `onDisappear`.
    func start() {
        subscribers += 1
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    func stop() {
        subscribers = max(0, subscribers - 1)
        guard subscribers == 0 else { return }
        timer?.invalidate()
        timer = nil
        previousTicks = nil
    }

    private func sample() {
        if let ticks = Self.readCPUTicks() {
            if let previousTicks {
                stats.cpu = CPUTicks.usage(from: previousTicks, to: ticks)
            }
            previousTicks = ticks
        }
        if let used = Self.readMemoryUsed() {
            stats.memoryUsed = used
        }
    }

    private static func readCPUTicks() -> CPUTicks? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info
        else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        var ticks = CPUTicks()
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * Int(CPU_STATE_MAX)
            ticks.user += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            ticks.system += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            ticks.idle += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            ticks.nice += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
        }
        return ticks
    }

    /// "Memory Used" as Activity Monitor shows it: app + wired + compressed.
    private static func readMemoryUsed() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_kernel_page_size)
        let app = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
        let used = app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return used * pageSize
    }
}
