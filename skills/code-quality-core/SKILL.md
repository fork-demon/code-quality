---
name: code-quality-core
description: >
  Core code quality standards that apply to EVERY code change — writing new code,
  modifying existing code, refactoring, or reviewing. Use by default whenever
  producing or changing code in any language.
---

# Code Quality Core

These standards apply to every piece of code you write or change. They are not
suggestions to consider at the end — apply them while writing.

## Design principles

- **Single responsibility.** A class/function does one thing. If you describe it
  with "and", split it.
- **Small units.** Functions under ~30 lines, classes under ~300. Long units are
  a smell that responsibilities are mixed.
- **Depend on abstractions at boundaries.** Inject dependencies through
  constructors/parameters; never reach out to globals, singletons, or static
  mutable state.
- **Low coupling, high cohesion.** A change in one module should not ripple into
  unrelated modules. Keep related behavior and data together.
- **Fail fast and loud.** Validate inputs at the boundary; throw specific
  exceptions with context. Never swallow exceptions or return silent nulls where
  an error occurred.
- **Immutability first.** Prefer final/immutable values and unmodifiable
  collections; mutate only when there is a measured reason.
- **No premature generality.** Do not add interfaces, patterns, config options,
  or extension points for hypothetical future needs (YAGNI). Three concrete uses
  justify an abstraction; one does not.

## Code hygiene

- **Names carry meaning.** Names describe intent (`retryDelayMs`, not `d`). No
  abbreviations the next reader must decode.
- **No dead code.** Delete unused code instead of commenting it out — version
  control remembers.
- **No copy-paste duplication.** Extract shared logic when you paste the same
  block a second time.
- **Comments explain WHY, not what.** If the code needs a "what" comment,
  rewrite the code to be clearer.
- **Consistent with the codebase.** Match existing naming, structure, and idiom
  of the surrounding code, even when you would personally choose differently.
- **No magic values.** Name numeric/string literals whose meaning is not obvious
  at the point of use.
- **Logging, not printing.** Use the project's logger, never stdout/stderr
  printing in production code.

## Error handling

- Catch the most specific exception type possible; never `catch (Exception)` or
  `catch (Throwable)` in business logic.
- Either handle an exception meaningfully, or let it propagate wrapped with
  context — never both log AND rethrow (double reporting), never neither
  (swallowing).
- Resources (streams, connections, clients) are closed via
  try-with-resources / equivalent deterministic disposal.

## Security basics (every change)

- Never build SQL/queries/commands by string concatenation with runtime values —
  use parameterized APIs.
- Never hardcode secrets, tokens, passwords, or URLs with credentials. Read them
  from configuration/environment.
- Validate and bound all external input (size, range, format) before use.
- Do not log secrets, tokens, or personal data.

## Definition of done

Code is not done when it compiles. Before declaring a task complete:

1. Re-read your diff as a reviewer would; fix what you would flag.
2. Tests exist for the new behavior (see [[writing-good-tests]]).
3. Static-analysis / lint checks configured in the repo pass (see
   [[fixing-static-analysis-findings]] when they don't).
4. No TODOs left for essential behavior — a TODO is only acceptable for a
   follow-up the user explicitly agreed to defer.
