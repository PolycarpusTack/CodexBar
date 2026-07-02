# ADR-4 — Structured errors; "unavailable on platform" is a first-class, non-fatal state

- **Status:** Accepted
- **Date:** 2026-06-30
- **Deciders:** Architect, Shell developer, engine engineers
- **Review by:** at the EPIC A/B retro

## Context

On Windows some providers cannot run (cookie/web providers per ADR-2; CLI-only
providers whose subprocess subsystem is walled per ADR-3). The shell must render
these clearly and keep every other provider working. A slow or unported provider
must never freeze or crash the panel (reliability NFR).

The CLI already emits a structured "requires macOS" error for `web` sources
(`CLIUsageCommand.swift`), which the shell must render as "unavailable", not treat
as a fault.

## Decision

Errors are **structured and part of Engine Contract v1**:

```json
{ "status": "error",
  "error": { "code": "...", "message": "...", "requiresPlatform": "macOS" } }
```

- `requiresPlatform` (optional) marks a provider that is unavailable on the current
  OS. The shell renders this as a friendly "Unavailable on Windows" row with the
  reason — a **first-class, non-fatal state**, not an exception.
- A non-zero CLI exit or a malformed payload also maps to a typed, non-fatal
  result in the Engine Client, never an unhandled exception.
- A failing/unavailable provider degrades independently; the rest of the panel is
  unaffected.

## Alternatives considered

- **Exit-code-only signalling** — rejected. Too coarse to distinguish
  "unavailable on this platform" from "token missing" from "transient fetch error,"
  and it gives the shell no message to show the user.

## Consequences

- User journey J4 / smoke ST-4 ("provider unavailable on Windows") is
  contract-defined and testable against golden payloads, not incidental behaviour.
- The Engine Client maps `{ ok | error | requiresPlatform | malformed | timeout }`
  to typed results (see companion `EngineClient`); the tray always has a state to
  render.
