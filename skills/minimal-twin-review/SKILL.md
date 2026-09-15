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

## Step 1 — Recover the task

From the diff, the commit messages, and the conversation, write the task in
one or two sentences: the behaviour that must exist afterwards, the contracts
that must not change. If it is unclear, ask before continuing.

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
- A real behaviour breaks that the twin lacks → the task statement was
  incomplete; add it to the task and keep the declaration.

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
