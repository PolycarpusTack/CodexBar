# ADR-3 — Isolate macOS/POSIX-only code so the engine builds on Windows

- **Status:** Accepted — **revised 2026-07-01 after the Windows port** (see "Revision")
- **Date:** 2026-06-30 (original) / 2026-07-01 (revised)
- **Deciders:** Eng lead, engine engineers
- **Review by:** if a non-Portable provider is requested on Windows, or if `serve` is revived

## Context

`CodexBarCore`/`CodexBarCLI` already build on macOS and Linux; Windows was "the
next platform, not the first." The build had macOS-only frameworks (WebKit,
Security/Keychain, OSLog) and POSIX-only seams (PATH resolution, process spawn,
PTY, BSD sockets). The open risk was whether the whole thing could compile on the
Swift-Windows toolchain — specifically whether the unconditional `SweetCookieKit`
dependency would block it.

## Original decision (2026-06-30, superseded in part)

> macOS-only code stays behind `#if os(macOS)`; Windows-needed POSIX pieces (paths,
> process spawn) get a Win32 abstraction; **`SweetCookieKit` is made a conditional
> (`#if os(macOS)`) dependency** so it can't block the Core build on Windows.

## Revision (2026-07-01 — what the port actually proved)

SPIKE A-1 and the MVP-subset port on branch `spike/windows-mvp` established:

1. **`SweetCookieKit` is NOT a compile blocker.** It resolves *and* compiles on
   Windows. Making it conditional was **unnecessary** and the dependency is left
   **unconditional**, keeping the manifest identical across platforms.
2. **The real blockers were a bounded subsystem, not the dependency:** the POSIX
   subprocess/PTY code (`Host/Process/*`, `Host/PTY/TTYCommandRunner`), a couple
   of Foundation-API gaps, and two masking imports (`CoreFoundation`, a bare
   `#else import Darwin`).

**Revised decision — the isolation strategy actually adopted:**

- **Wall the subprocess/PTY subsystem** behind `#if !os(Windows)`
  (`Host/Process/*`, `Host/PTY/TTYCommandRunner`, and CLI-session/status-probe
  files that use raw, *unguarded* POSIX), plus provide Windows public API via
  `Host/WindowsHostStubs.swift` and `Providers/WindowsProviderStubs.swift`.
- **Port the foundational seams** rather than abstracting them wholesale:
  `PathEnvironment` (`%USERPROFILE%`, `PATHEXT`, `.exe`; login-shell PATH capture
  is a no-op on Windows), `CodexOAuthCredentials` write-back, `CostUsageScanner`
  cache helpers, `CookieHeaderCache` (in-process lock only).
- **Exclude `CLILocalHTTPServer.swift` / `serve` from the Windows build**
  (`#if !os(Windows)`) — the one-shot CLI is the seam (ADR-1); `serve` is deferred
  (TD-2).
- **Leave `SweetCookieKit` unconditional.** It compiles; conditionalising it would
  be churn for no benefit.
- **Only wall files with *unguarded* raw POSIX.** Files whose POSIX is already
  `#if os(macOS)`-gated compile on Windows like Linux; walling them wrongly removes
  members production code depends on.
- The provider **registry is untouched** — all providers still enumerate; CLI-only
  providers degrade to "unavailable" at runtime on Windows (see ADR-4), rather than
  being compiled out.

The macOS and Linux build/test paths are unchanged by this work.

## Consequences

- Core + CLI compile, link, and run on Windows (`21,547 → 0` Core errors, ~40 files
  changed, all on branch). Codex OAuth-file fetch returns real usage.
- New Windows-specific debt is tracked: TD-4 (satisfying `SweetCookieKit`'s unconditional
  `-lsqlite3` — now a ~70 KB import lib for the OS `winsqlite3.dll`, regenerable from a committed
  `sqlite3.def`; A2-2), TD-5 (CLI providers stubbed on Windows), TD-6 (credential write-back —
  RESOLVED via `MoveFileExW(MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)`, an atomic durable
  rename). Note: the built exe imports no `winsqlite3.dll` — no sqlite symbol is reachable in the
  MVP, so `-lsqlite3` is purely a link-flag requirement.
- Reviving a walled subsystem (CLI providers, `serve`) is a bounded, well-marked
  follow-up, not a redesign.
