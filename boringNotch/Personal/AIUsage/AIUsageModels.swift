//
//  AIUsageModels.swift
//  boringNotch
//
//  Subscription usage windows for AI coding tools and the JSON parsers
//  for each provider's (unofficial) usage endpoint.
//

import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case claude, codex, antigravity

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .antigravity: "Antigravity"
        }
    }

    var symbol: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .antigravity: "arrow.up.circle"
        }
    }
}

struct UsageWindow: Equatable, Identifiable {
    var id: String { label }
    let label: String
    /// 0...100
    let usedPercent: Double
    let resetsAt: Date?
}

struct ProviderUsage: Equatable, Identifiable {
    var id: AIProvider { provider }
    let provider: AIProvider
    var windows: [UsageWindow] = []
    var plan: String?
    var error: String?
    var updatedAt = Date()

    /// Highest usage across windows, used for the compact summary.
    var peakPercent: Double { windows.map(\.usedPercent).max() ?? 0 }
}

enum AIUsageParser {
    enum ParseError: Error { case invalid }

    /// `GET https://api.anthropic.com/api/oauth/usage`:
    /// `{"five_hour": {"utilization": 12.0, "resets_at": "…"}, "seven_day": {…}, "seven_day_opus": null, …}`
    static func parseClaude(_ data: Data) throws -> [UsageWindow] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalid
        }
        let order = ["five_hour", "seven_day", "seven_day_sonnet", "seven_day_opus"]
        let labels = ["five_hour": "5h", "seven_day": "Week", "seven_day_sonnet": "Sonnet wk", "seven_day_opus": "Opus wk"]
        let keys = json.keys.sorted { (order.firstIndex(of: $0) ?? 99, $0) < (order.firstIndex(of: $1) ?? 99, $1) }
        return keys.compactMap { key in
            guard let window = json[key] as? [String: Any],
                  let used = (window["utilization"] as? NSNumber)?.doubleValue else { return nil }
            let resets = (window["resets_at"] as? String).flatMap(parseISODate)
            return UsageWindow(label: labels[key] ?? key.replacingOccurrences(of: "_", with: " "),
                               usedPercent: used, resetsAt: resets)
        }
    }

    /// `GET https://chatgpt.com/backend-api/wham/usage`:
    /// `{"plan_type": "plus", "rate_limit": {"primary_window": {"used_percent": 3, "limit_window_seconds": 18000, "reset_at": 1795748639}, "secondary_window": {…}}}`
    static func parseCodex(_ data: Data) throws -> (plan: String?, windows: [UsageWindow]) {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParseError.invalid
        }
        let limits = json["rate_limit"] as? [String: Any] ?? [:]
        let windows = ["primary_window", "secondary_window"].compactMap { key -> UsageWindow? in
            guard let window = limits[key] as? [String: Any],
                  let used = (window["used_percent"] as? NSNumber)?.doubleValue else { return nil }
            let seconds = (window["limit_window_seconds"] as? NSNumber)?.intValue
            let resets = (window["reset_at"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            return UsageWindow(label: windowLabel(seconds: seconds), usedPercent: used, resetsAt: resets)
        }
        return (json["plan_type"] as? String, windows)
    }

    /// Antigravity language server `GetUserStatus`: per-model quota as `remainingFraction`.
    static func parseAntigravity(_ data: Data) throws -> [UsageWindow] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["userStatus"] as? [String: Any] else { throw ParseError.invalid }
        let configs = (status["cascadeModelConfigData"] as? [String: Any])?["clientModelConfigs"] as? [[String: Any]] ?? []
        return configs.compactMap { config in
            guard let label = config["label"] as? String,
                  let quota = config["quotaInfo"] as? [String: Any] else { return nil }
            let remaining = (quota["remainingFraction"] as? NSNumber)?.doubleValue ?? 0
            let resets = (quota["resetTime"] as? String).flatMap(parseISODate)
            return UsageWindow(label: label, usedPercent: (1 - remaining) * 100, resetsAt: resets)
        }
    }

    static func windowLabel(seconds: Int?) -> String {
        guard let seconds else { return "Limit" }
        switch seconds {
        case ..<86_400: return "\(max(seconds / 3600, 1))h"
        case 604_800: return "Week"
        default: return "\(seconds / 86_400)d"
        }
    }

    static func parseISODate(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
