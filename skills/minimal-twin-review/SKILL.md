---
name: minimal-twin-review
description: >
  Review a change by measuring it against a minimal twin: an independent,
  smallest-correct implementation of what was asked. Produces a verbosity
  ratio and a delete list. Use for /quality-review, /done, before pushing, or
  when asked whether a change is too big or over-engineered.
---

# Minimal Twin Review

Linters and PR bots check what is *wrong*. This checks what is *unnecessary*.
Reviewers normally have nothing to compare a change against; the twin gives
them that. Five principles, applied with judgement — not a checklist.

## 1. The brief describes behaviour, never structure

The twin is built from acceptance criteria in Given / When / Then form:
observable behaviour at the public surface, plus the contracts that must not
change. Never types, methods, patterns, files or "how". That format cannot
leak a solution, whatever the change looks like.

## 2. The brief is what was asked — use the best record you have

In order of reliability: feature files in the change; what the harness
recorded the developer asking (`.git/qc-prompts/<branch>.md`) or what they
asked in this conversation; criteria already recorded on the commit or PR;
and only if nothing else exists, what the change observably does. Condense
to a handful of scenarios; on contradictions the last word wins. Check the
change for behaviour no record mentions (hand edits happen) and include it.
Then ask the developer once — "is this what you asked for?" — and wait.
Say in the report where the brief came from; a brief inferred from the change
makes a weaker twin.

## 3. The twin is built blind

Hand the brief and a scratch checkout of the base branch (`git worktree add
/tmp/twin <base>`) to the `twin-builder` subagent. It sees nothing else — not
the diff, not the branch. Without subagents, build it yourself in the
worktree before re-reading the diff and say so. The twin must actually meet
the brief; if it drops a requirement, send it back. It is a yardstick, never
a candidate to merge. Remove the worktree when done.

## 4. Measure the whole change; justify or delete

Everything in the diff counts, whoever or whatever wrote it.
**Verbosity ratio** = lines added ÷ lines the twin needed. For every
declaration (type, method, field, parameter, config knob, dependency) the
change has and the twin does not, ask one question by reading the code:
*what breaks if this is deleted and its caller inlined?* Nothing → delete.
Only its own test → delete both. A behaviour the brief lacks → the brief was
incomplete: add it, extend the twin, recount. Ask the same question of
comments that restate code, guards on impossible paths, logging beyond the
owning layer, re-validation, and wrappers around methods that only return or
throw.

## 5. The twin measures size, not quality

Smaller is the yardstick, not the standard. The repo's conventions and the
`code-quality-core` / `writing-good-tests` skills still say what good code
looks like, for the change and for the twin alike; a twin that is small by
being dense, or by ignoring an existing utility, is wrong — fix it. When the
twin reused something the change reinvented, the delete-list entry is "use
the existing X".

Two short passes against the real diff that size cannot answer: are the
criteria tested at their boundaries and would the tests fail if the logic
were deleted ([[writing-good-tests]]); and is there a security gap scanners
miss — missing authorisation, trusted external input, secrets or personal
data in logs. `fail` is reserved for a bug, a vulnerability, a broken
contract, or untested behaviour. A large ratio alone is *pass-with-majors*.
Zero findings is a valid result.

## Output

```
Verdict: pass | pass-with-minors | pass-with-majors | fail
Brief: <scenarios, one line each> (source: feature files | prompt log | conversation | recorded | inferred)
Twin: +<n> lines, <k> declarations      Actual: +<m> lines, <j> declarations
Verbosity ratio: <m/n>x   Removable: ~<lines>
Delete list — declaration: what breaks (nothing | only its own test)
Keep list   — declaration: the behaviour it protects
Tests / Security — findings
```

Finish by offering to apply the delete list — deletions first, then the
repo's build checks — and to record the brief on the commit under
`Acceptance criteria:` so the next review starts from it.
