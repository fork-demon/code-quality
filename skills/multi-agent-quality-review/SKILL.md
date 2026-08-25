---
name: multi-agent-quality-review
description: >
  Run a multi-perspective quality review of a change using parallel reviewer
  agents (design, tests, maintainability, security) and merge their findings
  into one verdict. Use when asked for a quality review, code review, or before
  merging a substantial change.
---

# Multi-Agent Quality Review

Review the change from four independent perspectives, then merge. If your
environment supports spawning subagents, run the four reviewers **in
parallel**, each with only its own lens. If it does not, perform the four
passes sequentially yourself — separately, not as one blended pass (a single
blended pass reliably misses what a focused lens catches).

## Scope

The unit of review is the current diff (working tree vs the base branch), or
the files the user names. Each reviewer receives: the diff, the surrounding
code it touches, and its lens instructions below.

## The four lenses

**1. Design reviewer** — structure and boundaries.
Apply [[code-quality-core]] and [[design-patterns]]: single responsibility,
coupling between the changed modules, dependency direction, unnecessary
abstraction/over-engineering, naming, consistency with the existing
architecture. Question: *will the next change in this area be easier or harder
because of this diff?*

**2. Test reviewer** — the safety net.
Apply [[writing-good-tests]]: does every new behavior have a test, do tests
assert behavior (not implementation), are edge and error cases covered, any
logic/flakiness/over-mocking in tests, were existing tests weakened to pass?

**3. Maintainability reviewer** — the reader's experience.
Readability of the diff in isolation: dead code, duplication introduced,
misleading names/comments, magic values, complexity that needs a comment but
lacks one, log messages that would not help during an incident.

**4. Security reviewer** — what can be abused.
Injection (SQL/command/path), unvalidated external input, secrets in code or
logs, unsafe deserialization, missing authorization checks on new entry points,
dependency additions with known-vulnerable versions, data exposure in error
messages.

## Reviewer output contract

Each reviewer returns findings as:

```
- [severity: blocker|major|minor] file:line — one-sentence issue — one-sentence fix
```

Severity meaning: **blocker** = must fix before merge (bug, vulnerability,
data loss, broken contract); **major** = should fix now (design/test debt that
will compound); **minor** = worth fixing, may defer with agreement.

Reviewers report only findings they are confident in — no speculative "you
might consider" padding. Zero findings is a valid result.

## Merge step

1. Deduplicate findings that multiple lenses caught (keep the highest severity).
2. Drop findings contradicted by code the reviewer didn't see — verify each
   blocker/major against the actual code before reporting it.
3. Present: verdict (**pass / pass-with-minors / fail**), findings grouped by
   severity, and — if fail — the shortest path to pass.

Findings from this review feed the normal fix loop in
[[fixing-static-analysis-findings]] step discipline: fix, re-run, confirm.
