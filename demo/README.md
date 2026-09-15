# Demo — done entirely inside the Tabnine agent

One small feature ("reject orders whose total quantity exceeds 100") on the
same base, implemented twice: the way fast AI generation tends to (+368 lines,
six new files) and the way it should be (+36 lines). Both behave identically,
both pass the repo's Checkstyle and PMD config, both have green tests. The
verbose one is what a rushed reviewer waves through.

## Set up (once)

```bash
PACK=/path/to/code-quality
cp -r "$PACK/demo/sample-app" /tmp/orders && cd /tmp/orders && git init -q -b main
git add -A && git commit -qm "Concise OrderService"
git checkout -q -b verbose && cp -r "$PACK/demo/verbose-change/src" . && git add -A \
  && git commit -qm "Add order total limit: orders whose total quantity exceeds 100 are rejected before any stock is reserved"
git checkout -q -b concise main && cp -r "$PACK/demo/concise-change/src" . && git add -A && git commit -qm "Add order total limit"
git checkout -q verbose
```

Install the pack's skills and commands into `/tmp/orders` (top-level README)
and open it in the agent.

## Walkthrough (about 10 minutes)

1. **The tools we already have are fine with it.** On `verbose`:
   `gradle check` — Checkstyle, PMD and tests all pass. `git diff --stat main`
   — +368 lines for one `if`. Point out that Sonar and the PR bots would pass
   this too: nothing is *wrong*, it is just three hundred lines nobody needed.

2. **`/quality-review`.** The agent builds the minimal twin from the task and
   the base code, without looking at the diff, then measures. Expected
   (`sample-review.md` is a recorded real run): twin +47 lines, actual +368,
   **verbosity ratio 7.8x**, a delete list where every entry says "nothing
   breaks", plus two things nobody planted: a null check that is dead code
   because a log line runs first, and customer IDs going into logs
   unsanitised. Four minutes, no tooling.

3. **Say yes.** The agent applies the delete list, deletions first, and re-runs
   `gradle check`. Watch the diff converge on the `concise` branch.

4. **`/done`.** Show the definition-of-done workflow on any real task: build
   checks, twin review, tests, honest summary with the ratio before and after.
   This is the loop developers run instead of a reviewer catching it later.

5. **Optional, the hook.** With `hooks/tabnine-settings.json` merged in, ask the
   agent to "make the checks pass" on a branch that fails Checkstyle. When it
   declares done, `gradle check` runs once and denies completion until the
   build is green — the repo's own rules, no rules of ours.

Close with `git diff --shortstat main..verbose` next to `main..concise`.
