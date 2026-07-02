# ADR-2 — Windows MVP ships Portable Providers only (no cookie scraping)

- **Status:** Accepted
- **Date:** 2026-07-01
- **Deciders:** Security, Eng lead, Architect
- **Review by:** before any cookie/web provider work (Future EPIC C)

## Context

Some providers authenticate via browser cookies (ChatGPT-web, Cursor). Reading
those requires scraping the browser cookie store — a privacy-sensitive operation
and, on Windows, an additional DPAPI/Credential-Manager surface. The companion's
hard security posture is: **no browser-cookie access by default, no prompt/content
capture, no password storage.**

## Decision

The Windows MVP anchors on **Portable Providers** — those whose credentials need
no cookie scraping:

- **Codex** — OAuth-file (`%USERPROFILE%\.codex\auth.json`) + HTTPS.
- **Copilot** — device-flow token + HTTPS.

Cookie/web providers are **off by default**. They may only be enabled when an
admin turns them on in Managed Config **and** an approved Windows cookie path
exists. They are out of the MVP.

## Alternatives considered

- **Enable cookie/web providers on Windows for parity with macOS** — rejected for
  the MVP. It violates the default-no-scraping constraint and pulls in the
  DPAPI/cookie-DB surface (Future EPIC C, requires its own spike).

## Consequences

- The MVP credential paths are OAuth-file / device-flow / API-key only —
  satisfying the no-scraping constraint.
- Cookie/web providers requested on Windows degrade to a first-class
  "unavailable on platform" state (see ADR-4), never a crash.
- Notably, this also let the Windows port avoid the entire subprocess/PTY
  subsystem, since both MVP providers are pure HTTP / HTTP+file (see ADR-3).
