# ADR-5 — Zero prompt/content in logs; telemetry opt-in, anonymous, Phase 3 only

- **Status:** Accepted
- **Date:** 2026-06-30
- **Deciders:** Security, Legal, Architect
- **Review by:** before any telemetry work (Future EPIC F, Phase 3)

## Context

The companion is an internal tool handling AI-usage signals. The org's hard
privacy posture is local-first with no surprise data collection. Trust in the tool
depends on it demonstrably never capturing what people type.

## Decision

- **No prompt/content capture, ever.** No raw prompt logging. Logs carry usage
  counts, provider ids, statuses, and errors only — never message content.
- **Structured logs** (`JSONStderrLogHandler`), local by default.
- **No telemetry until Phase 3**, and then only **opt-in and anonymous**, gated on
  Security + Legal sign-off. Managed Config's `telemetry` flag defaults to `false`.
- Smoke tests assert **zero prompt/content** appears in logs or toasts
  (A-8 / B-7).

## Alternatives considered

- **Default-on anonymous usage telemetry** — rejected for the MVP. Even anonymous
  collection needs sign-off and opt-in; shipping it on by default would undermine
  the local-first trust posture.

## Consequences

- Any new log line or toast is subject to the zero-content rule; the smokes are the
  enforcement point.
- Telemetry remains a deliberate, gated, later phase — not an incidental capability.
