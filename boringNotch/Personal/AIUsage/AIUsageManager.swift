//
//  AIUsageManager.swift
//  boringNotch
//
//  Fetches subscription usage for Claude Code, Codex and Antigravity using
//  the logins those tools already store locally. Tokens are only read, never
//  refreshed: refreshing would rotate the tool's refresh token and log it out.
//

import Defaults
import Foundation
import Security

@MainActor
final class AIUsageManager: ObservableObject {
    static let shared = AIUsageManager()

    @Published private(set) var usage: [ProviderUsage] = []
    @Published private(set) var isRefreshing = false

    private var timer: Timer?
    private var lastRefresh: Date?
    private var claudeToken: (value: String, expires: Date?)?
    /// Set when the user denies the Keychain prompt; cleared by a manual refresh.
    private var claudeKeychainDenied = false

    private init() {}

    var enabledProviders: [AIProvider] {
        AIProvider.allCases.filter { provider in
            switch provider {
            case .claude: Defaults[.aiUsageClaude]
            case .codex: Defaults[.aiUsageCodex]
            case .antigravity: Defaults[.aiUsageAntigravity]
            }
        }
    }

    func setEnabled(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { @MainActor in await AIUsageManager.shared.refresh() }
        }
        Task { await refresh() }
    }

    /// Refreshes when the data is older than `maxAge`; used when the tab opens.
    func refreshIfStale(maxAge: TimeInterval = 60) {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < maxAge { return }
        Task { await refresh() }
    }

    /// Manual refresh from the AI tab: also retries a denied Keychain prompt.
    func userRefresh() async {
        claudeKeychainDenied = false
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        var results: [ProviderUsage] = []
        for provider in enabledProviders {
            results.append(await fetch(provider))
        }
        usage = results
        lastRefresh = Date()
    }

    private func fetch(_ provider: AIProvider) async -> ProviderUsage {
        do {
            switch provider {
            case .claude: return try await fetchClaude()
            case .codex: return try await fetchCodex()
            case .antigravity: return try await fetchAntigravity()
            }
        } catch let error as UsageError {
            return ProviderUsage(provider: provider, error: error.message)
        } catch {
            return ProviderUsage(provider: provider, error: "Unavailable")
        }
    }

    // MARK: Claude

    private func fetchClaude() async throws -> ProviderUsage {
        let token = try await claudeAccessToken()
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await Self.send(request)
        return ProviderUsage(provider: .claude, windows: try AIUsageParser.parseClaude(data))
    }

    private func claudeAccessToken() async throws -> String {
        if let cached = claudeToken, (cached.expires ?? .distantFuture) > Date() {
            return cached.value
        }
        guard !claudeKeychainDenied else { throw UsageError("Keychain access denied, tap refresh") }
        let keychain = await Self.keychainPassword(service: "Claude Code-credentials")
        if keychain == nil { claudeKeychainDenied = true }
        let data = keychain
            ?? (try? Data(contentsOf: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/.credentials.json")))
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw UsageError("Sign in to Claude Code")
        }
        let expires = (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        if let expires, expires <= Date() {
            throw UsageError("Login expired, open Claude Code")
        }
        claudeToken = (token, expires)
        return token
    }

    // MARK: Codex

    private func fetchCodex() async throws -> ProviderUsage {
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = json["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String else {
            throw UsageError("Sign in to Codex")
        }
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let account = tokens["account_id"] as? String {
            request.setValue(account, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let parsed = try AIUsageParser.parseCodex(try await Self.send(request))
        return ProviderUsage(provider: .codex, windows: parsed.windows, plan: parsed.plan?.capitalized)
    }

    // MARK: Antigravity (experimental)

    /// Asks the running Antigravity language server for its model quotas.
    private func fetchAntigravity() async throws -> ProviderUsage {
        guard let server = await Self.antigravityServer() else {
            throw UsageError("Antigravity is not running")
        }
        let body = #"{"metadata":{"ideName":"antigravity","extensionName":"antigravity","locale":"en"}}"#
        for port in server.ports {
            for scheme in ["https", "http"] {
                let url = URL(string: "\(scheme)://127.0.0.1:\(port)/exa.language_server_pb.LanguageServerService/GetUserStatus")!
                var request = URLRequest(url: url, timeoutInterval: 3)
                request.httpMethod = "POST"
                request.httpBody = Data(body.utf8)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
                request.setValue(server.csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")
                if let data = try? await Self.send(request, session: LocalhostSession.shared.session),
                   let windows = try? AIUsageParser.parseAntigravity(data), !windows.isEmpty {
                    return ProviderUsage(provider: .antigravity, windows: windows)
                }
            }
        }
        throw UsageError("Quota unavailable")
    }

    private static func antigravityServer() async -> (csrfToken: String, ports: [Int])? {
        await Task.detached {
            guard let ps = run("/bin/ps", ["-axo", "pid=,command="]) else { return nil }
            for line in ps.split(separator: "\n") where line.contains("language_server") && line.lowercased().contains("antigravity") {
                let parts = line.split(separator: " ")
                guard let pid = parts.first,
                      let csrfIndex = parts.firstIndex(where: { $0 == "--csrf_token" }),
                      csrfIndex + 1 < parts.count else { continue }
                let lsof = run("/usr/sbin/lsof", ["-nP", "-a", "-iTCP", "-sTCP:LISTEN", "-p", String(pid)]) ?? ""
                let ports = lsof.split(separator: "\n").compactMap { row -> Int? in
                    guard let address = row.split(separator: " ").first(where: { $0.contains("127.0.0.1:") || $0.contains("*:") }) else { return nil }
                    return address.split(separator: ":").last.flatMap { Int($0) }
                }
                return (String(parts[csrfIndex + 1]), ports)
            }
            return nil
        }.value
    }

    // MARK: Helpers

    struct UsageError: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }

    private static func send(_ request: URLRequest, session: URLSession = .shared) async throws -> Data {
        var request = request
        request.timeoutInterval = min(request.timeoutInterval, 15)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: return data
        case 401, 403: throw UsageError("Login expired, sign in again")
        case 429: throw UsageError("Rate limited, try later")
        default: throw UsageError("HTTP \(status)")
        }
    }

    /// Reads the item through Apple's `security` tool rather than the
    /// Security framework: the Keychain then remembers "Always Allow" for that
    /// stable, Apple-signed binary, instead of for this ad-hoc signed app whose
    /// signature changes on every build and so prompts again each time.
    private static func keychainPassword(service: String) async -> Data? {
        await Task.detached {
            guard let output = run("/usr/bin/security", ["find-generic-password", "-s", service, "-w"]) else { return nil }
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : Data(trimmed.utf8)
        }.value
    }

    nonisolated private static func run(_ path: String, _ args: [String]) -> String? {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        guard (try? proc.run()) != nil else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}

/// URLSession that accepts the self-signed certificate of local language servers.
private final class LocalhostSession: NSObject, URLSessionDelegate {
    static let shared = LocalhostSession()
    lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.host == "127.0.0.1", let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
