#if os(Windows)
import Foundation

/// POSIX process id type, used in many CLI-provider signatures. Windows has no POSIX `pid_t`;
/// alias it to Int32 so those signatures compile (the CLI code paths are unreachable on Windows).
public typealias pid_t = Int32

/// Antigravity CLI session (real version drives a local `agy` process; compiled out on Windows).
final class AntigravityCLISession: @unchecked Sendable {
    static let shared = AntigravityCLISession()
    func beginProbe(binary _: String, idleWindow _: TimeInterval? = nil) async throws -> pid_t {
        throw WindowsUnsupportedProvider.cli("Antigravity")
    }

    func reset() async {}
    func drainOutput() -> Data {
        Data()
    }

    func finishProbe(success _: Bool, resetAfterFetch _: Bool, forceTerminate _: Bool = false) async {}
}

enum AntigravityCLIAuthenticationPrompt {
    static func contains(_: Data) -> Bool {
        false
    }
}

/// Thrown by CLI-provider fetch paths that require the (Windows-unsupported) subprocess subsystem.
enum WindowsUnsupportedProvider: LocalizedError {
    case cli(String)
    var errorDescription: String? {
        switch self {
        case let .cli(name): "\(name) is not available on Windows (requires a local CLI/PTY)."
        }
    }
}

// Windows stubs for CLI-provider entry points that portable (registry/HTTP) code still references.
// The real implementations live in files compiled out on Windows (`#if !os(Windows)`) because they
// drive child processes / PTYs. CLI providers are not part of the Windows MVP; these keep the shared
// code compiling and degrade the CLI paths to "unavailable" at runtime.

/// Throttle gate for the Codex CLI RPC launch (real version lives in CodexCLILaunchGate.swift).
enum CodexCLILaunchGate {
    static let shared = CodexCLILaunchGateStub()
}

struct CodexCLILaunchGateStub {
    func backgroundSkipMessage(binary _: String) -> String? {
        nil
    }

    func recordLaunchFailure(binary _: String, message _: String) -> String? {
        nil
    }
}

/// Subset of CodexStatusProbe's error surface referenced by shared code + the CLI target.
public enum CodexStatusProbeError: Error {
    case codexNotInstalled
    case timedOut
}

/// Subset of GeminiStatusProbe's error surface referenced by the CLI error mapper.
public enum GeminiStatusProbeError: Error {
    case geminiNotInstalled
    case notLoggedIn
    case unsupportedAuthType(String)
    case parseFailed(String)
    case timedOut
    case apiError(String)
}

/// Subset of ClaudeStatusProbe's error surface referenced by shared error-classifier helpers.
enum ClaudeStatusProbeError: Error {
    case timedOut
    case parseFailed(String)
}

/// Minimal ClaudeStatusProbe surface referenced by portable code (the CLI probe itself is
/// compiled out on Windows). `probeWorkingDirectoryURL` is pure Foundation and mirrors the real one.
enum ClaudeStatusProbe {
    static func probeWorkingDirectoryURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        return base
            .appendingPathComponent("CodexBar", isDirectory: true)
            .appendingPathComponent("ClaudeProbe", isDirectory: true)
    }
}
#endif
