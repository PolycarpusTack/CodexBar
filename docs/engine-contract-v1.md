# Engine Contract v1

The stable JSON shape the **Shell** (WinUI 3 on Windows; any external consumer) depends on from the
Engine CLI. Produced by:

```
CodexBarCLI usage --provider <id> --format json --json-only
```

Output is a JSON **array** of provider results (one element per fetched provider). The Shell must
treat the contract as **forward-compatible**: unknown fields may be added at any time and MUST be
ignored; only the *pinned* fields below are guaranteed. Removing/renaming/retyping a pinned field is
a breaking change (guarded by `TestsLinux/EngineContractV1Tests.swift`).

> Contract version is tracked in this document + the test, not (yet) in the payload — the current
> CLI does not emit a `schemaVersion` field. A future normalized envelope (with `schemaVersion`/
> `status`) would be **Contract v2**; see backlog A2-2/notes. v1 pins the *actual* current output.

## Pinned fields

Top level (array element):

| Field | Type | Notes |
|---|---|---|
| `provider` | string | Provider id (e.g. `"codex"`). **Required.** |
| `source` | string | Data source used (`oauth`, `cli`, `web`, `api`). |
| `usage` | object | Present on success; see below. |
| `credits` | object\|null | Credit balance, if the provider has one. |

`usage`:

| Field | Type | Notes |
|---|---|---|
| `primary` | object\|null | The main RateWindow (see Window). |
| `secondary` | object\|null | Secondary window (e.g. weekly). |
| `tertiary` | object\|null | Optional third window. |
| `dataConfidence` | string | `exact` \| `estimated` \| `percentOnly` \| `unknown`. |
| `identity` | object\|null | `{ providerID, accountEmail, loginMethod }`. |
| `updatedAt` | string (ISO-8601) | When the snapshot was produced. |

Window (`primary`/`secondary`/`tertiary`):

| Field | Type | Notes |
|---|---|---|
| `usedPercent` | number | 0–100 (may be fractional). **Required in a window.** |
| `windowMinutes` | integer | Window length (e.g. `300` = 5h, `10080` = weekly). **Required in a window.** |
| `resetsAt` | string (ISO-8601)\|null | When the window resets. |
| `resetDescription` | string\|null | Human label (e.g. `"8:57 PM"`). |

`credits`:

| Field | Type | Notes |
|---|---|---|
| `remaining` | number\|null | Credits remaining. |
| `updatedAt` | string\|null | ISO-8601. |
| `events` | array | Provider-specific; not pinned. |

## Example (Codex, `--source oauth`)

```json
[{"provider":"codex","source":"oauth",
  "usage":{
    "primary":{"usedPercent":1,"windowMinutes":300,"resetsAt":"2026-07-01T18:57:20Z","resetDescription":"8:57 PM"},
    "secondary":{"usedPercent":0,"windowMinutes":10080,"resetsAt":"2026-07-08T13:57:20Z","resetDescription":"Jul 8 at 3:57 PM"},
    "tertiary":null,
    "dataConfidence":"exact",
    "identity":{"providerID":"codex","accountEmail":"user@example.com","loginMethod":"plus"},
    "updatedAt":"2026-07-01T13:57:21Z"},
  "credits":{"remaining":0,"updatedAt":"2026-07-01T13:57:21Z","events":[]}}]
```

## Machine schema + contract test
- JSON Schema: `docs/engine-contract-v1.json` (draft-07, `additionalProperties: true` = forward-compatible).
- Contract test: `TestsLinux/EngineContractV1Tests.swift` — decodes a golden payload into the pinned
  Codable subset and asserts the pinned fields; also asserts an unknown extra field does not break
  decoding. Runs in the Linux/Windows test target (A-3 CI).
