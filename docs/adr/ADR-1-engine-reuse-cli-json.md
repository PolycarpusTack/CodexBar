# ADR-1 — Reuse the Swift engine via a versioned one-shot CLI JSON contract

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** Eng lead, Architect
- **Review by:** at the EPIC A/B retro, or if the one-shot invocation proves insufficient

## Context

The AI Usage Companion needs provider usage data (used/limit/reset windows) on
Windows. All ~69 provider parsers, the `RateWindow`/reset math, and credential
flows already exist in `CodexBarCore`, driven by `CodexBarCLI`, which already
emits machine-readable JSON (`--format json --json-only`) and can run a local
HTTP server (`serve`).

The alternative — re-deriving provider logic in the shell's native language —
is the single largest and most error-prone body of work in the project, for no
functional gain.

## Decision

The Windows shell is a **consumer of a versioned JSON contract** emitted by
`CodexBarCLI`. It never re-implements provider parsing.

- **Primary seam:** one-shot invocation —
  `CodexBarCLI usage --provider <id> --format json --json-only` (stdout JSON,
  exit code = status). No long-lived process, no socket, no port/auth surface.
- The payload conforms to **Engine Contract v1** (`docs/engine-contract-v1.md` /
  `.json`), a pinned subset with a contract test that fails CI on field drift.

## Alternatives considered

- **Rust/TypeScript rewrite of the providers** — rejected. Re-deriving 69
  providers' parsing, auth, and reset-window math is the most expensive path and
  carries ongoing correctness risk.
- **`serve` / local-HTTP transport** — deferred. `CLILocalHTTPServer` uses BSD
  sockets with no Winsock path (see TD-2). The one-shot CLI avoids the port and
  bearer-token surface entirely. Revisit only if one-shot proves insufficient
  (Future EPIC G).

## Consequences

- The shell depends on a stable, small, versioned surface — not on engine
  internals. Field drift is caught by the Contract v1 test, not at runtime.
- Each fetch pays subprocess-spawn cost; acceptable for an interval poll of a
  handful of Portable Providers (well within the < 5 s fetch SLO).
- `serve`/Winsock work is out of scope until a concrete need appears.
