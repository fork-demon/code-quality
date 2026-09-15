# Minimal Twin — a prompt-only quality workflow for the Tabnine agent

**North star:** with agents generating most of the code, keep quality enforced
even when a human reviewer misses — using only prompts and the harness's own
workflow, so there is nothing to maintain as the models move.

CI already has Sonar, Checkstyle, Snyk, tests and PR review agents. They check
what is *wrong*. None of them check what is *unnecessary*, and that is what
AI-generated code gets wrong most: interfaces with one implementation, helpers
with one caller, builders for one field, comments restating code, guards on
impossible paths, logging at every layer. It passes every gate and compounds
across hundreds of fast PRs.

```
skills/     3 SKILL.md files
agents/     twin-builder — the isolated subagent that builds the yardstick
commands/   /quality-review, /done
hooks/      optional: one line that runs the repo's own `gradle check` at turn end
demo/       sample repo, verbose vs concise change, recorded real review, deck
```

Whole pack: ~300 lines of markdown and TOML.

No scripts, no rulesets, no runners, nothing versioned against a tool.

## The idea: measure against a minimal twin

`minimal-twin-review` does not list smells. It hands the task statement and a
scratch checkout of the base branch to the **`twin-builder` subagent**, which
implements the task as small as correctly possible in its own context window —
it never sees the diff, so it cannot be anchored by it — and then measures the
real change against that twin:

- **Verbosity ratio** = lines added ÷ lines the twin needed.
- **Delete list** = every declaration the real diff added that the twin did
  not, each answered with *what breaks if I delete it?* — by reading the
  code, not guessing. "Nothing" is a finding.
- Short tests and security-gap passes for what the twin cannot see.

On the demo change a real run reported: twin +47 lines, actual +368,
**ratio 7.8x**, seven deletable declarations, one dead null check, one
log-injection surface. See `demo/sample-review.md`. That is a number to put on
a slide, and it comes from a prompt. (That run had no subagent available and
built the twin inline before reading the diff — the isolated version is the
one to demo.)

## The workflow

| | When | What |
|---|---|---|
| `code-quality-core` | always on | Write the least code that fully solves the task; the delete list; non-negotiables; never edit a gate to pass it; definition of done. |
| `writing-good-tests` | on tests | Behaviour over implementation, no logic in tests, follow the repo's own fakes. |
| `/quality-review` | before pushing | The minimal-twin review; offers to apply the delete list. |
| `/done` | before saying "done" | `gradle check` green → twin review applied → tests at boundaries → honest summary with the ratio before/after. |
| `hooks/tabnine-settings.json` | optional, once per task | `./gradlew -q check` on task completion; non-zero denies "done". The repo's rules, not ours. |

Nothing runs per iteration. Deterministic rules stay in the build and CI; the
agent applies judgement; `/done` makes the judgement part of finishing.

## Install (Tabnine CLI — paths verified against the docs)

Everything goes under `<repo>/.tabnine/agent/` (or `~/.tabnine/agent/` for
all repos). Symlink to this pack so updates propagate.

| What | Where | Notes |
|---|---|---|
| Skills | `.tabnine/agent/skills/<name>/SKILL.md` | Agent Skills standard; `.agents/skills/` is an accepted alias. Activated by description or by name. |
| Commands | `.tabnine/agent/commands/quality-review.toml`, `done.toml` | TOML, `prompt` + `description`, `{{args}}`. |
| Subagent | `.tabnine/agent/agents/twin-builder.md` | Needs `"experimental": { "enableAgents": true }` in settings. Own context window, tool allowlist, 25 turns / 8 min. |
| Hook (optional) | merge `hooks/tabnine-settings.json` into `.tabnine/agent/settings.json` | `AfterAgent` fires once per turn; returns `decision: "deny"` with the build output when `gradle check` fails. Needs `jq`. |

No installer: with one harness and eight files, the table above *is* the
installer. Revisit if a second harness or a third team needs it.

Claude Code and Gemini CLI read the same skills; the commands translate 1:1
and the subagent maps to their agent-definition format.

## Demo

`demo/README.md` — ten minutes inside the agent: the linters pass the verbose
change, `/quality-review` measures it at 7.8x and finds two real defects, the
agent deletes its way to the concise version, `/done` shows the loop.

## Keeping it honest

Replace the delete list in `code-quality-core` with your own evidence: pull the
human review comments from the last 30–50 merged PRs, bucket them, keep what
recurs. And track the ratio: if the median twin ratio of merged PRs drops over
a quarter, the pack works; if it doesn't, delete the pack.

## What changed from v1 and why

| v1 | now | Reason |
|---|---|---|
| `qcheck.sh` + bundled rulesets after every iteration | Gone. Optional hook runs the repo's own `gradle check` once per task | Deterministic checks belong in the build; a second ruleset drifts; per-iteration blocking interrupts without enforcing |
| Generic best-practice skills (patterns table, line counts, naming) | Three short skills aimed at over-production | Models know the generic material; the gap is verbosity |
| Multi-agent lens review | Minimal-twin review | Lenses restate what PR bots do; the twin produces a measurement nothing else does |
| Scripts to run and parse the review | None — the agent runs it, reads it, applies it | Nothing to maintain as harnesses and models change |
