# Architecture Decision Records — AI Usage Companion (Windows enablement)

These ADRs capture the cross-cutting decisions behind reusing `CodexBarCore` /
`CodexBarCLI` as the shared **Engine** for the Windows "AI Usage Companion" shell.
They are recorded here (in the engine repo) because they constrain the engine's
build and public contract, not just the shell.

They originate from the companion solution design (`ai-usage-companion-plan/02-solution-design.md`
§9) and were made concrete by the Windows MVP-subset port on branch `spike/windows-mvp`.

| ADR | Decision | Status |
|-----|----------|--------|
| [ADR-1](ADR-1-engine-reuse-cli-json.md) | Reuse the Swift engine via a versioned one-shot CLI JSON contract | Accepted |
| [ADR-2](ADR-2-credential-strategy.md) | Windows MVP ships Portable Providers only (no cookie scraping) | Accepted |
| [ADR-3](ADR-3-platform-isolation.md) | Isolate macOS/POSIX-only code so the engine builds on Windows | Accepted (revised — see doc) |
| [ADR-4](ADR-4-error-format.md) | Structured errors; "unavailable on platform" is a first-class, non-fatal state | Accepted |
| [ADR-5](ADR-5-observability-privacy.md) | Zero prompt/content in logs; telemetry opt-in, anonymous, Phase 3 only | Accepted |

> ADR-1, ADR-3, ADR-4 were authored under backlog task A-2-T2. ADR-2 and ADR-5 are
> honoured cross-cutting constraints (slated for EPIC B); they are recorded here now
> because both are already decided and the set reads better complete.
