---
name: code-quality-core
description: >
  Always-on standard for any code change. Targets what AI-generated code gets
  wrong that linters cannot catch — over-production — plus the definition of
  done and the rules for interacting with quality gates. Apply while writing,
  not after.
---

# Code Quality Core

Formatting, naming, complexity, nullness and known bug patterns are owned by the
repo's deterministic tools (Spotless, Checkstyle, PMD, ErrorProne, NullAway,
Sonar, Snyk). Do not re-derive their rules; run them and fix what they report.
This skill covers what they cannot see.

## The one rule: write the least code that fully solves the task

Generated code tends to over-produce. Before finishing, re-read your diff and
delete anything on this list unless the task or the surrounding code demands it:

- **Interface + single implementation** (`Foo` / `FooImpl`, `DefaultFoo`) with
  no second implementation and no test seam needed.
- **Helper/Util/Manager classes or private methods with one caller** that only
  delegate or wrap a call. Inline them.
- **Builders, factories, config knobs, generics, or extension points** for a
  single caller or a hypothetical future need.
- **Comments and Javadoc that restate the code** (`// increment counter`,
  `@param id the id`). Keep only comments that explain *why*.
- **Defensive checks on paths that cannot fail**: null checks on values already
  validated or non-null by contract, try/catch around code that cannot throw.
- **Catch-log-rethrow, or catch-and-wrap without adding information.** Let it
  propagate, or handle it at the layer that can decide.
- **Logging at every layer / for every branch.** Log where an incident
  responder needs it, once.
- **Re-validation** of input already validated at the boundary.
- **Result/Response wrapper objects** for a method that can simply return the
  value or throw.
- **Dead code, unused imports, commented-out code, TODOs for the current task.**

A diff that adds a class per concept is a smell; the simplest structure that
resolves the *present* forces wins. Three concrete uses justify an abstraction;
one does not. Match the idioms of the surrounding code even when you would
choose differently.

## Non-negotiables (every change)

- Parameterized queries/commands; never concatenate runtime values into them.
- No secrets, tokens, or credentialed URLs in code or logs; no personal data in logs.
- Bound and validate external input once, at the boundary.
- Resources closed deterministically (try-with-resources or equivalent).

## Quality gates

- **Never edit a gate to pass it**: no changes to ruleset XML, thresholds,
  baselines, exclude lists, or CI config to get green. Those belong to humans.
- **No blanket suppressions** (`@SuppressWarnings` at file/class level,
  `NOPMD` / `CHECKSTYLE:OFF` regions). A single-line, single-rule suppression is
  allowed only for a demonstrable false positive, with a justifying comment,
  and you tell the user you added it.
- Fix the root cause the rule protects against, not the minimum edit that
  silences it. After three fix cycles, stop and report what remains.

## Definition of done

1. Re-read the full diff as a reviewer; apply the delete list above.
2. New behavior has a test in the same change (see [[writing-good-tests]]).
3. The repo's build and static checks pass locally, without touching their config.
4. Summary to the user states what was added, what was deliberately *not*
   added, and any suppression or deferred item.
