#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
#if canImport(WinSDK)
import WinSDK
#endif
import Foundation

public struct CodexOAuthCredentials: Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let idToken: String?
    public let accountId: String?
    public let lastRefresh: Date?

    public init(
        accessToken: String,
        refreshToken: String,
        idToken: String?,
        accountId: String?,
        lastRefresh: Date?)
    {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.accountId = accountId
        self.lastRefresh = lastRefresh
    }

    public var needsRefresh: Bool {
        guard let lastRefresh else { return true }
        let eightDays: TimeInterval = 8 * 24 * 60 * 60
        return Date().timeIntervalSince(lastRefresh) > eightDays
    }
}

public enum CodexOAuthCredentialsError: LocalizedError, Sendable {
    case notFound
    case decodeFailed(String)
    case missingTokens

    public var errorDescription: String? {
        switch self {
        case .notFound:
            "Codex auth.json not found. Run `codex` to log in."
        case let .decodeFailed(message):
            "Failed to decode Codex credentials: \(message)"
        case .missingTokens:
            "Codex auth.json exists but contains no tokens."
        }
    }
}

public enum CodexOAuthCredentialsStore {
    private static func authFilePath(
        env: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default) -> URL
    {
        CodexHomeScope
            .ambientHomeURL(env: env, fileManager: fileManager)
            .appendingPathComponent("auth.json")
    }

    public static func load(env: [String: String] = ProcessInfo.processInfo
        .environment) throws -> CodexOAuthCredentials
    {
        let url = self.authFilePath(env: env)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CodexOAuthCredentialsError.notFound
        }

        let data = try Data(contentsOf: url)
        return try self.parse(data: data)
    }

    public static func parse(data: Data) throws -> CodexOAuthCredentials {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CodexOAuthCredentialsError.decodeFailed("Invalid JSON")
        }

        if let apiKey = json["OPENAI_API_KEY"] as? String,
           !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            return CodexOAuthCredentials(
                accessToken: apiKey,
                refreshToken: "",
                idToken: nil,
                accountId: nil,
                lastRefresh: nil)
        }

        guard let tokens = json["tokens"] as? [String: Any] else {
            throw CodexOAuthCredentialsError.missingTokens
        }
        guard let accessToken = Self.stringValue(in: tokens, snakeCaseKey: "access_token", camelCaseKey: "accessToken"),
              let refreshToken = Self.stringValue(
                  in: tokens,
                  snakeCaseKey: "refresh_token",
                  camelCaseKey: "refreshToken"),
              !accessToken.isEmpty
        else {
            throw CodexOAuthCredentialsError.missingTokens
        }

        let idToken = Self.stringValue(in: tokens, snakeCaseKey: "id_token", camelCaseKey: "idToken")
        let accountId = Self.stringValue(in: tokens, snakeCaseKey: "account_id", camelCaseKey: "accountId")
        let lastRefresh = Self.parseLastRefresh(from: json["last_refresh"])

        return CodexOAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            accountId: accountId,
            lastRefresh: lastRefresh)
    }

    public static func save(
        _ credentials: CodexOAuthCredentials,
        env: [String: String] = ProcessInfo.processInfo.environment) throws
    {
        let url = self.authFilePath(env: env)

        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            json = existing
        }

        var tokens: [String: Any] = [
            "access_token": credentials.accessToken,
            "refresh_token": credentials.refreshToken,
        ]
        if let idToken = credentials.idToken {
            tokens["id_token"] = idToken
        }
        if let accountId = credentials.accountId {
            tokens["account_id"] = accountId
        }

        json["tokens"] = tokens
        json["last_refresh"] = ISO8601DateFormatter().string(from: Date())

        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try self.writePrivateFile(data, to: url)
    }

    private static func writePrivateFile(
        _ data: Data,
        to url: URL,
        beforePublish: ((URL) throws -> Void)? = nil) throws
    {
        let fileManager = FileManager.default
        let stagedURL = url.deletingLastPathComponent().appendingPathComponent(
            ".\(url.lastPathComponent).codexbar-staged-\(UUID().uuidString)",
            isDirectory: false)
        #if os(Windows)
        // Windows: no POSIX 0600/O_EXCL; stage then atomically replace via Foundation.
        do {
            try data.write(to: stagedURL, options: .atomic)
            try beforePublish?(stagedURL)
            try self.renameItem(at: stagedURL, to: url)
        } catch {
            try? fileManager.removeItem(at: stagedURL)
            throw error
        }
        return
        #else
        let stagedPath = stagedURL.path
        let descriptor = stagedPath.withCString {
            open($0, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode_t(0o600))
        }
        guard descriptor >= 0 else {
            throw self.posixError(code: errno, path: stagedPath)
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var handleIsOpen = true
        do {
            guard fchmod(descriptor, mode_t(0o600)) == 0 else {
                throw self.posixError(code: errno, path: stagedPath)
            }
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
            handleIsOpen = false

            try beforePublish?(stagedURL)
            try self.renameItem(at: stagedURL, to: url)
        } catch {
            if handleIsOpen {
                try? handle.close()
            }
            try? fileManager.removeItem(at: stagedURL)
            throw error
        }
        #endif
    }

    private static func renameItem(at sourceURL: URL, to destinationURL: URL) throws {
        #if os(Windows)
        // swift-corelibs-foundation on Windows doesn't implement replaceItemAt. Use Win32
        // MoveFileExW with MOVEFILE_REPLACE_EXISTING to replace the destination atomically (a
        // single rename, no remove-then-move gap), and MOVEFILE_WRITE_THROUGH so the credential
        // file is flushed to disk before we return (durable token refresh). Supersedes TD-6.
        func widePath(_ url: URL) -> [UInt16] {
            url.withUnsafeFileSystemRepresentation { rep in
                guard let rep else { return [UInt16]() }
                return Array(String(cString: rep).utf16) + [0]
            }
        }
        let source = widePath(sourceURL)
        let destination = widePath(destinationURL)
        let flags = DWORD(MOVEFILE_REPLACE_EXISTING) | DWORD(MOVEFILE_WRITE_THROUGH)
        let moved = source.withUnsafeBufferPointer { src in
            destination.withUnsafeBufferPointer { dst in
                MoveFileExW(src.baseAddress, dst.baseAddress, flags)
            }
        }
        guard moved else {
            throw NSError(
                domain: "Win32.MoveFileExW",
                code: Int(GetLastError()),
                userInfo: [NSFilePathErrorKey: destinationURL.path])
        }
        return
        #else
        let result = sourceURL.path.withCString { sourcePath in
            destinationURL.path.withCString { destinationPath in
                rename(sourcePath, destinationPath)
            }
        }
        guard result == 0 else {
            throw self.posixError(code: errno, path: destinationURL.path)
        }
        #endif
    }

    private static func posixError(code: Int32, path: String) -> NSError {
        NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(code),
            userInfo: [NSFilePathErrorKey: path])
    }

    private static func parseLastRefresh(from raw: Any?) -> Date? {
        guard let value = raw as? String, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func stringValue(
        in dictionary: [String: Any],
        snakeCaseKey: String,
        camelCaseKey: String)
        -> String?
    {
        if let value = dictionary[snakeCaseKey] as? String, !value.isEmpty {
            return value
        }
        if let value = dictionary[camelCaseKey] as? String, !value.isEmpty {
            return value
        }
        return nil
    }
}

#if DEBUG
extension CodexOAuthCredentialsStore {
    static func _authFileURLForTesting(env: [String: String]) -> URL {
        self.authFilePath(env: env)
    }

    static func _writePrivateFileForTesting(
        _ data: Data,
        to url: URL,
        beforePublish: @escaping (URL) throws -> Void) throws
    {
        try self.writePrivateFile(data, to: url, beforePublish: beforePublish)
    }
}
#endif
