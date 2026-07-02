import Foundation
import Testing
@testable import CodexBarCore

/// A2-3 audit: credential/PATH resolution for the two Windows MVP Portable providers must resolve
/// from the correct location or return a structured "not connected" state — verified by tests, not
/// Codex-by-luck. These are platform-neutral (they use env injection), so they also exercise the
/// Windows paths (`%USERPROFILE%\.codex`, `MoveFileExW` write-back) when run in Windows CI.
@Suite
struct WindowsPortableCredentialTests {
    private func freshCodexHome() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-a2-3-\(UUID().uuidString)", isDirectory: true)
    }

    // MARK: Codex OAuth-file (Portable provider) — path resolution

    @Test
    func codexAuthFileResolvesUnderCodexHome() {
        let home = self.freshCodexHome()
        let url = CodexOAuthCredentialsStore._authFileURLForTesting(env: ["CODEX_HOME": home.path])
        #expect(url.lastPathComponent == "auth.json")
        #expect(url.deletingLastPathComponent().standardizedFileURL.path
            == home.standardizedFileURL.path)
    }

    @Test
    func codexAmbientHomeIsDotCodexUnderUserHome() {
        // With no CODEX_HOME, the dir is `<home>/.codex` — the real Windows location is
        // `%USERPROFILE%\.codex`, since Foundation's homeDirectoryForCurrentUser maps to it.
        let url = CodexHomeScope.ambientHomeURL(env: [:])
        #expect(url.lastPathComponent == ".codex")
        #expect(url.deletingLastPathComponent().standardizedFileURL.path
            == FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path)
    }

    // MARK: Codex — structured "not connected"

    @Test
    func codexLoadMissingFileThrowsNotFound() {
        let home = self.freshCodexHome()
        #expect(throws: CodexOAuthCredentialsError.self) {
            _ = try CodexOAuthCredentialsStore.load(env: ["CODEX_HOME": home.path])
        }
    }

    // MARK: Codex — round-trip + TD-6 atomic replace over an existing file

    @Test
    func codexSaveThenLoadRoundTrips() throws {
        let home = self.freshCodexHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let env = ["CODEX_HOME": home.path]

        let creds = CodexOAuthCredentials(
            accessToken: "at-1", refreshToken: "rt-1",
            idToken: "id-1", accountId: "acc-1", lastRefresh: Date())
        try CodexOAuthCredentialsStore.save(creds, env: env)

        let loaded = try CodexOAuthCredentialsStore.load(env: env)
        #expect(loaded.accessToken == "at-1")
        #expect(loaded.refreshToken == "rt-1")
        #expect(loaded.accountId == "acc-1")
    }

    @Test
    func codexSaveOverExistingReplacesCleanly() throws {
        // Exercises the hardened write-back: on Windows this is MoveFileExW(REPLACE_EXISTING),
        // which must overwrite the prior auth.json and leave no staged temp files behind.
        let home = self.freshCodexHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let env = ["CODEX_HOME": home.path]

        try CodexOAuthCredentialsStore.save(
            CodexOAuthCredentials(accessToken: "old", refreshToken: "old-r",
                                  idToken: nil, accountId: nil, lastRefresh: Date()),
            env: env)
        try CodexOAuthCredentialsStore.save(
            CodexOAuthCredentials(accessToken: "new", refreshToken: "new-r",
                                  idToken: nil, accountId: nil, lastRefresh: Date()),
            env: env)

        let loaded = try CodexOAuthCredentialsStore.load(env: env)
        #expect(loaded.accessToken == "new")
        #expect(loaded.refreshToken == "new-r")

        // No leftover staged (`.auth.json.codexbar-staged-*`) files — replace was clean.
        let entries = try FileManager.default.contentsOfDirectory(atPath: home.path)
        #expect(entries == ["auth.json"])
    }

    // MARK: Copilot device-flow / API token (Portable provider) — env resolution

    @Test
    func copilotResolvesFromEnvToken() {
        let token = ProviderTokenResolver.copilotToken(environment: ["COPILOT_API_TOKEN": "ghu_example"])
        #expect(token == "ghu_example")
    }

    @Test
    func copilotAbsentOrBlankTokenResolvesNil() {
        #expect(ProviderTokenResolver.copilotToken(environment: [:]) == nil)
        #expect(ProviderTokenResolver.copilotToken(environment: ["COPILOT_API_TOKEN": "   "]) == nil)
    }
}
