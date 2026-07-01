#if os(Windows)
import Foundation

// Windows shim for the subprocess/PTY host subsystem.
//
// On macOS/Linux these types live in Host/Process/* and Host/PTY/* and drive real
// child processes via posix_spawn + PTYs. Those files are compiled out on Windows
// (`#if !os(Windows)`), so this file re-declares the public surface that portable
// (non-CLI) code still references. CLI-driven providers are not part of the Windows
// MVP; their execution entry points throw `.launchFailed`. `which`/`enrichedPath`
// are implemented for real so binary discovery still works.

public enum SubprocessRunnerError: LocalizedError, Sendable {
    case binaryNotFound(String)
    case launchFailed(String)
    case timedOut(String)
    case nonZeroExit(code: Int32, stderr: String)

    public var errorDescription: String? {
        switch self {
        case let .binaryNotFound(binary):
            return "Missing CLI '\(binary)'. Install it and restart CodexBar."
        case let .launchFailed(details):
            return "Failed to launch process: \(details)"
        case let .timedOut(label):
            return "Command timed out: \(label)"
        case let .nonZeroExit(code, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "Command failed with exit code \(code)."
                : "Command failed (\(code)): \(trimmed)"
        }
    }
}

public struct SubprocessResult: Sendable {
    public let stdout: String
    public let stderr: String

    public init(stdout: String, stderr: String) {
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum SubprocessRunner {
    public static func run(
        binary: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval,
        standardInput: Any? = nil,
        currentDirectoryURL: URL? = nil,
        label: String) async throws -> SubprocessResult
    {
        _ = (binary, arguments, environment, timeout, standardInput, currentDirectoryURL, label)
        throw SubprocessRunnerError.launchFailed("Subprocess execution is not supported on Windows (MVP).")
    }
}

public struct TTYCommandRunner {
    public struct Result: Sendable {
        public enum Completion: Sendable, Equatable {
            case processExited(status: Int32)
            case idleTimeout
            case outputCondition
            case deadlineExceeded
        }

        public let text: String
        public let completion: Completion
    }

    public struct Options: Sendable {
        public var rows: UInt16 = 50
        public var cols: UInt16 = 160
        public var timeout: TimeInterval = 20.0
        public var idleTimeout: TimeInterval?
        public var workingDirectory: URL?
        public var extraArgs: [String] = []
        public var baseEnvironment: [String: String]?
        public var initialDelay: TimeInterval = 0.4
        public var sendEnterEvery: TimeInterval?
        public var sendOnSubstrings: [String: String]
        public var stopOnURL: Bool
        public var stopOnSubstrings: [String]
        public var settleAfterStop: TimeInterval
        public var forceCodexStatusMode: Bool
        public var useClaudeProbeWorkingDirectory: Bool
        public var returnOnEmptyProcessExit: Bool
        public var cancellationCheck: @Sendable () -> Bool

        public init(
            rows: UInt16 = 50,
            cols: UInt16 = 160,
            timeout: TimeInterval = 20.0,
            idleTimeout: TimeInterval? = nil,
            workingDirectory: URL? = nil,
            extraArgs: [String] = [],
            baseEnvironment: [String: String]? = nil,
            initialDelay: TimeInterval = 0.4,
            sendEnterEvery: TimeInterval? = nil,
            sendOnSubstrings: [String: String] = [:],
            stopOnURL: Bool = false,
            stopOnSubstrings: [String] = [],
            settleAfterStop: TimeInterval = 0.25,
            forceCodexStatusMode: Bool = false,
            useClaudeProbeWorkingDirectory: Bool = false,
            returnOnEmptyProcessExit: Bool = false,
            cancellationCheck: @escaping @Sendable () -> Bool = { Task<Never, Never>.isCancelled })
        {
            self.rows = rows
            self.cols = cols
            self.timeout = timeout
            self.idleTimeout = idleTimeout
            self.workingDirectory = workingDirectory
            self.extraArgs = extraArgs
            self.baseEnvironment = baseEnvironment
            self.initialDelay = initialDelay
            self.sendEnterEvery = sendEnterEvery
            self.sendOnSubstrings = sendOnSubstrings
            self.stopOnURL = stopOnURL
            self.stopOnSubstrings = stopOnSubstrings
            self.settleAfterStop = settleAfterStop
            self.forceCodexStatusMode = forceCodexStatusMode
            self.useClaudeProbeWorkingDirectory = useClaudeProbeWorkingDirectory
            self.returnOnEmptyProcessExit = returnOnEmptyProcessExit
            self.cancellationCheck = cancellationCheck
        }
    }

    public enum Error: Swift.Error, LocalizedError, Sendable {
        case binaryNotFound(String)
        case launchFailed(String)
        case timedOut

        public var errorDescription: String? {
            switch self {
            case let .binaryNotFound(bin):
                "Missing CLI '\(bin)'. Install it or add it to PATH."
            case let .launchFailed(msg): "Failed to launch process: \(msg)"
            case .timedOut: "PTY command timed out."
            }
        }
    }

    public init() {}

    public func run(
        binary: String,
        send script: String,
        options: Options = Options(),
        onURLDetected: (@Sendable () -> Void)? = nil) throws -> Result
    {
        _ = (binary, script, options, onURLDetected)
        throw Error.launchFailed("Interactive PTY commands are not supported on Windows (MVP).")
    }

    public static func terminateActiveProcessesForAppShutdown() {}

    /// Real PATH-based executable lookup so binary discovery still works on Windows.
    public static func which(_ tool: String) -> String? {
        if tool == "codex", let located = BinaryLocator.resolveCodexBinary() { return located }
        if tool == "claude", let located = BinaryLocator.resolveClaudeBinary() { return located }

        let fileManager = FileManager.default
        let env = ProcessInfo.processInfo.environment
        let pathSeparator: Character = ";"
        let dirs = (env["PATH"] ?? "").split(separator: pathSeparator).map(String.init)
        // PATHEXT drives implicit extension resolution on Windows (e.g. `.EXE`, `.CMD`).
        let exts = (env["PATHEXT"] ?? ".COM;.EXE;.BAT;.CMD")
            .split(separator: pathSeparator).map { String($0).lowercased() }
        let hasExt = tool.contains(".")

        for dir in dirs where !dir.isEmpty {
            let base = dir.hasSuffix("\\") ? String(dir.dropLast()) : dir
            if hasExt {
                let candidate = "\(base)\\\(tool)"
                if fileManager.isExecutableFile(atPath: candidate) { return candidate }
            } else {
                for ext in exts {
                    let candidate = "\(base)\\\(tool)\(ext)"
                    if fileManager.isExecutableFile(atPath: candidate) { return candidate }
                }
            }
        }
        return nil
    }

    public static func enrichedPath() -> String {
        PathBuilder.effectivePATH(
            purposes: [.tty, .nodeTooling],
            env: ProcessInfo.processInfo.environment)
    }

    static func enrichedEnvironment(
        baseEnv: [String: String] = ProcessInfo.processInfo.environment,
        loginPATH: [String]? = LoginShellPathCache.shared.current,
        home _: String = NSHomeDirectory()) -> [String: String]
    {
        var env = baseEnv
        env["PATH"] = PathBuilder.effectivePATH(
            purposes: [.tty, .nodeTooling],
            env: baseEnv,
            loginPATH: loginPATH)
        return env
    }
}
#endif
