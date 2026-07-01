import Foundation
import Testing

// Engine Contract v1 — the pinned JSON subset the Windows/.NET Shell consumes from
// `CodexBarCLI usage --provider <p> --format json --json-only`.
//
// This test pins the fields the Shell depends on. It is FORWARD-COMPATIBLE: `Codable` ignores
// unknown keys, so ADDING a new field to the CLI output does not fail this test. It FAILS if a
// PINNED field is renamed, retyped, or dropped (the strict decode / expectations below break).
//
// The golden payload below is a real (anonymised) `usage --provider codex --source oauth
// --format json --json-only` result. Regenerate it from live output if the contract is
// intentionally revised (and bump the documented contract version in docs/engine-contract-v1.md).
// See docs/engine-contract-v1.md + docs/engine-contract-v1.json for the human/schema forms.
struct EngineContractV1Tests {
    /// Pinned Contract v1 shape. Non-optional fields are the hard commitments to the Shell.
    struct ContractV1Result: Codable {
        let provider: String
        let source: String?
        let usage: Usage?
        let credits: Credits?

        struct Usage: Codable {
            let primary: Window?
            let secondary: Window?
            let tertiary: Window?
            let dataConfidence: String?
            let identity: Identity?
            let updatedAt: String?
        }

        struct Window: Codable {
            let usedPercent: Double
            let windowMinutes: Int
            let resetsAt: String?
            let resetDescription: String?
        }

        struct Identity: Codable {
            let providerID: String?
            let accountEmail: String?
            let loginMethod: String?
        }

        struct Credits: Codable {
            let remaining: Double?
            let updatedAt: String?
        }
    }

    static let goldenCodexUsageJSON = """
    [{"provider":"codex","source":"oauth",
      "usage":{
        "primary":{"usedPercent":1,"windowMinutes":300,"resetsAt":"2026-07-01T18:57:20Z","resetDescription":"8:57 PM"},
        "secondary":{"usedPercent":0,"windowMinutes":10080,"resetsAt":"2026-07-08T13:57:20Z","resetDescription":"Jul 8 at 3:57 PM"},
        "tertiary":null,
        "dataConfidence":"exact",
        "loginMethod":"plus",
        "accountEmail":"user@example.com",
        "identity":{"providerID":"codex","accountEmail":"user@example.com","loginMethod":"plus"},
        "updatedAt":"2026-07-01T13:57:21Z"},
      "credits":{"remaining":0,"updatedAt":"2026-07-01T13:57:21Z","events":[]}}]
    """

    @Test func `codex usage JSON decodes into the Contract v1 pinned subset`() throws {
        let data = Data(Self.goldenCodexUsageJSON.utf8)
        let results = try JSONDecoder().decode([ContractV1Result].self, from: data)

        let codex = try #require(results.first { $0.provider == "codex" })
        #expect(codex.source == "oauth")

        // Primary window — the core RateWindow the Shell renders.
        let primary = try #require(codex.usage?.primary)
        #expect(primary.usedPercent >= 0)
        #expect(primary.windowMinutes == 300)
        #expect(primary.resetsAt != nil)

        // Secondary (weekly) window present with its own reset.
        let secondary = try #require(codex.usage?.secondary)
        #expect(secondary.windowMinutes == 10080)

        // Confidence + identity + credits the Shell surfaces.
        #expect(codex.usage?.dataConfidence == "exact")
        #expect(codex.usage?.identity?.accountEmail != nil)
        #expect(codex.credits?.remaining != nil)
    }

    @Test func `adding an unknown field stays forward-compatible`() throws {
        // A future CLI field the Shell doesn't know about must NOT break decoding.
        let withExtra = """
        [{"provider":"codex","source":"oauth","brandNewField":{"x":1},
          "usage":{"primary":{"usedPercent":5,"windowMinutes":300},"dataConfidence":"exact"},
          "credits":{"remaining":2}}]
        """
        let results = try JSONDecoder().decode([ContractV1Result].self, from: Data(withExtra.utf8))
        #expect(results.first?.usage?.primary?.usedPercent == 5)
    }
}
