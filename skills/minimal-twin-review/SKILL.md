---
name: minimal-twin-review
description: >
  Review a change by building a minimal twin: independently implement the same
  task as small as correctly possible, then measure the real diff against it.
  Produces a verbosity ratio and a delete list. Use for /quality-review, before
  pushing, or when asked whether a change is over-engineered or too long.
---

# Minimal Twin Review

Linters and PR bots check what is *wrong*. This checks what is *unnecessary* —
the thing generated code gets wrong most. The method: build the smallest
correct implementation of the same task, then justify every line the real
diff has beyond it.

## Step 1 — State the task as acceptance criteria

The twin is only a fair yardstick if its brief could have been written before
the change existed and cannot describe a solution. So the brief is never
prose about the code: it is **acceptance criteria in Given / When / Then
form** — observable behaviour at the public surface, nothing about types,
methods, patterns or files. That format cannot leak structure, however the
change was produced. Take the criteria from the first available source:

1. **Feature files.** Scenarios added or changed by the diff (`*.feature`,
   Cucumber/BDD). Use them verbatim. The strongest case, not a requirement.
2. **The harness prompt log.** If `.git/qc-prompts/<branch>.md` exists (the
   `prompt-log` hook records every prompt the developer typed on this
   branch, in order), condense the whole log — every request, including
   corrections and reversals; the last word wins — into 3–6 scenarios. Show
   them to the developer with "is this what you asked for?" and wait. This
   needs no discipline from anyone: the harness wrote the log.
3. **Criteria already recorded** in the commit message (`Acceptance
   criteria:`), PR description or ticket.
4. **The conversation**, if it holds the requests and there is no log.
5. **Extracted.** Only when none of the above exist (reviewing an old
   change): derive scenarios from the tests the diff adds and from the
   diff's observable behaviour — inputs, outputs, exceptions, side effects.
   Say in the report that the criteria were extracted; the twin is weaker.

Whatever the source, the criteria go into the commit message under
`Acceptance criteria:` when the change is finished, so the next review of it
starts at source 3.

Before asking for confirmation, reconcile against the change itself: list
any observable behaviour the diff adds that no source above mentions (a
developer may have added it by hand in the IDE) and ask whether it belongs in
the criteria. Describe it as behaviour, never as structure. Everything in the
diff is measured regardless of who or what wrote it; this step only makes
sure the brief is complete.

Also list the contracts that must not change (existing public API, existing
tests). If the criteria are unclear or contradictory, ask the user; do not
guess.

## Step 2 — Build the twin (isolated)

Create a scratch checkout of the base branch (`git worktree add /tmp/twin
<base>`), then hand the task statement and that path to the **`twin-builder`**
subagent (`agents/twin-builder.md`). It runs in its own context window and
receives nothing else — not the diff, not the current branch — so it cannot be
anchored by the change under review. If the environment has no subagents, do
the twin yourself in the scratch checkout *before* re-reading the diff, and
say in the report that the twin was not isolated.

Sanity-check the twin: it must actually satisfy the task. If it cheats (drops
a requirement), send it back with the missing requirement. Remove the
worktree when done (`git worktree remove /tmp/twin`).

## Step 3 — Measure

- **Verbosity ratio** = lines added by the real diff ÷ lines added by the
  twin. Under 1.5: fine. 1.5–3: report the excess. Over 3: the change is
  over-produced; the review verdict is at best *pass-with-majors*.
- **Extra declarations** = every type, method, field, constructor parameter,
  config knob or dependency the real diff added that the twin did not.

## Step 4 — Justify or delete

For each extra declaration ask: *what breaks if this is deleted and its
caller inlined?* Read the code; do not guess.

- Nothing breaks → **delete** (finding, severity major).
- Only tests of the scaffolding itself break → **delete both**.
- A real behaviour breaks that the twin also has → the twin is wrong; fix it
  and recount.
- A real behaviour breaks that the twin lacks → the criteria were
  incomplete; keep the declaration, add the behaviour to the criteria, send
  the addition to `twin-builder` to extend the twin, and recount the ratio.

Then run the same question over the non-declaration additions: comments and
Javadoc that restate the code, null/try-catch guards on paths that cannot
fail, logging beyond the layer that owns the decision, re-validation of
already-validated input, result wrappers around a method that only returns
or throws.

## Step 5 — The twin does not check everything

Two short passes the twin cannot answer, done against the real diff:

- **Tests** ([[writing-good-tests]]): is every new behaviour tested at its
  boundaries, would the tests still pass with the logic deleted, were existing
  tests weakened, did the diff switch from the repo's real fakes to mocks?
- **Security gaps**: new entry points without authorisation, trust decisions
  on external input, secrets or personal data in logs or error messages.
  Only what scanners cannot see.

## Output

```
Verdict: pass | pass-with-minors | pass-with-majors | fail
Task: <one sentence>
Twin: +<n> lines, <k> declarations        Actual: +<m> lines, <j> declarations
Verbosity ratio: <m/n>x   Removable: ~<lines>

Delete list  (declaration — what breaks if deleted: nothing / only its own test)
Keep list    (declaration — the behaviour it protects)
Tests        (findings)
Security     (findings)
```

`fail` only for a bug, a vulnerability, a broken contract, or a new behaviour
with no test. Zero findings is a valid result. Finish by offering to apply
the delete list — deletions first, then re-run the repo's build checks.
