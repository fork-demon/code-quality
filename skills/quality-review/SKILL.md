---
name: quality-review
description: >
  Review a code change the way a good senior engineer does, with one concrete
  check per question: is any of it unnecessary, does it fit this codebase, do
  the tests really test it, is it safe at the edges. Use for /quality-review,
  /done, before pushing, or when asked whether a change is good enough.
---

# Quality Review

Linters and PR bots find what is *wrong*. This review asks the four
questions they cannot, and each question has one concrete way to check it.
Use judgement; these are not checklists. If a check cannot be run, say so
and fall back to reading the code.

## Ground rules

- Everything in the change is reviewed, whoever or whatever wrote it.
- Say where each finding came from and how sure you are.
- Only a bug, a vulnerability, a broken contract, or a behaviour with no real
  test can make the verdict `fail`. Everything else is a finding to fix or
  discuss. No findings is a valid result.
- Never modify tracked files during the review. Offer to apply the fixes
  after, deletions first, then the repo's own build checks.

## 1. Is any of it unnecessary?

**Check: build a minimal twin and compare.**

Write the change's brief as a few Given / When / Then scenarios — what must
be true afterwards and what must not change, never how. Take them from the
best record available: feature files in the change, the prompts the harness
recorded (`.git/qc-prompts/<branch>.md`) or this conversation, criteria on
the commit or PR, and only if nothing else exists, what the change observably
does. Include behaviour the change has that no record mentions, then ask the
developer once: "is this what you asked for?"

Give the brief and a scratch checkout of the base (`git worktree add
/tmp/twin <base>`) to the `twin-builder` subagent. It sees nothing else, so
it cannot copy the change. It makes the scenarios pass with the fewest new
lines in the repo's own style. It is a yardstick, never something to merge.
Without subagents, build it yourself before re-reading the change and say so.

Then: **verbosity ratio** = lines the change added ÷ lines the twin needed.
For everything the change has that the twin does not — a type, method,
field, parameter, config value, dependency, comment, guard, log line — ask
one question by reading the code: *what breaks if this is deleted?* Nothing →
delete. Only its own test → delete both. A real behaviour the brief missed →
add it to the brief, extend the twin, recount. Remove the worktree when done.

## 2. Does it fit this codebase?

**Check: find the nearest neighbour and compare.**

Find the existing code that does the most similar thing — same kind of
validation, same kind of service method, same kind of test. Compare
approach, naming, error handling, which helpers and types are used. If the
change solves the same shape of problem differently from the code next to
it, or writes its own version of something the repo already has, that is a
finding: "do it the way X does it" or "use the existing Y". If the twin
reused something the change reinvented, the same finding applies. If there
is no neighbour, say so and judge fit by the repo's conventions alone.

## 3. Do the tests really test it?

**Check: break the logic and run the tests.**

For each scenario in the brief, temporarily make the new logic wrong (flip
the comparison, return early, drop the check), run the tests, then restore.
If the tests stay green, they are not testing that behaviour; that is a
finding, and an untested behaviour makes the verdict `fail`. Also look for
the usual ways generated tests lie: a mock verifying every call instead of
asserting an outcome, a test weakened to accept the new output, a boundary
(exactly at the limit, empty, error path) with no test at all. If tests
cannot run here, read them and say the check was not executed.

## 4. Is it safe and right at the edges?

**Check: walk the boundaries and the inputs.**

For each input the change touches: what happens at the exact limit, at
empty, at null or absent, at the first failure in a loop? Read the code
path; do not assume. For each thing the change does with data: does
external input reach a query, a command, a log line or an error message
unchecked? Does a new entry point skip an authorisation step its neighbours
have? Do secrets or personal data end up in logs? Only report what a scanner
cannot see.

## Output

```
Verdict: pass | pass-with-minors | pass-with-majors | fail
Brief: <scenarios, one line each> (source: feature files | prompt log | conversation | recorded | inferred)

1 Unnecessary   Twin +<n> lines vs change +<m>  →  ratio <m/n>x, ~<k> removable
                delete list: <thing> — what breaks: nothing | only its own test
2 Fit           <finding — do it like X / use existing Y>, or "consistent with <neighbour>"
3 Tests         <scenario — tests stayed green with logic broken>, or "all scenarios protected"
4 Edges         <finding>, or "boundaries and inputs checked"
```

End by offering to apply the findings — deletions first, then fit, then
tests — and to record the brief on the commit under `Acceptance criteria:`.
