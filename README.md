# Minimal Twin: a prompt-only review workflow for AI-generated code

**Goal:** with agents writing most of the code, keep quality enforced even when
a human reviewer misses, using only prompts and the harness's own workflow, so
there is nothing to maintain as the models move.

CI already has Sonar, Checkstyle, Snyk, tests and PR review agents. They find
what is *wrong*. A good senior reviewer asks four more questions that none of
them can, and those are exactly where fast AI-generated code slips: is any of
it unnecessary, does it fit this codebase, do the tests really test it, is it
safe at the edges. This pack makes the agent ask them, with one concrete
check per question.

```
skills/     3 SKILL.md files — code-quality-core, writing-good-tests, quality-review
agents/     twin-builder — the isolated subagent that builds the yardstick for question 1
commands/   /quality-review, /done
hooks/      optional: one line that runs the repo's own `gradle check` at turn end
demo/       sample repo, verbose vs concise change, recorded real review, deck (code-quality.pptx)
```

Whole pack: ~300 lines of markdown and TOML.

No scripts, no rulesets, no runners, nothing versioned against a tool.

## The review: four questions, one check each

| Question | The check |
|---|---|
| **1. Is any of it unnecessary?** | Build a *minimal twin*: the `twin-builder` subagent gets only the brief (Given/When/Then, from feature files or the prompts the harness recorded, confirmed by the developer once) and a checkout of the base, and makes it pass with the fewest new lines. Compare: verbosity ratio, and for every extra thing, "what breaks if I delete it?" |
| **2. Does it fit this codebase?** | Find the nearest neighbour — the existing code that does the most similar thing — and compare approach, helpers, naming, error handling. "Do it the way X does it" / "use the existing Y". |
| **3. Do the tests really test it?** | Break the new logic on purpose and run the tests. Still green means not tested. |
| **4. Is it safe at the edges?** | Walk the exact limit, empty, null, first failure; follow external input to queries, logs, errors; check new entry points against their neighbours' authorisation. |

On the demo change a real run of question 1 reported: twin +47 lines, actual
+368, **ratio 7.8x**, seven deletable declarations — and, while reading, a
dead null check and a log-injection surface (questions 3 and 4). See
`demo/sample-review.md`. (That run predates the subagent and the other three
checks; the live review does more.)

## The workflow

| | When | What |
|---|---|---|
| `code-quality-core` | always on | Write the least code that fully solves the task; the delete list; non-negotiables; never edit a gate to pass it; definition of done. |
| `writing-good-tests` | on tests | Behaviour over implementation, no logic in tests, follow the repo's own fakes. |
| `/quality-review` | before pushing | The four-question review; offers to apply the findings. |
| `/done` | before saying "done" | `gradle check` green → review applied → criteria recorded on the commit → honest summary with the ratio before/after. |
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
| Hooks (optional, one line each) | merge `hooks/tabnine-settings.json` into `.tabnine/agent/settings.json` | `BeforeAgent` **prompt-log**: records every prompt the developer types to `.git/qc-prompts/<branch>.md` (never committed) so the twin's brief comes from what was actually asked, however disorganised. `AfterAgent` **build-checks**: `gradle check` once per turn, `decision: "deny"` on failure. Needs `jq`. |

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
| Multi-agent lens review | Four questions, one concrete check each (twin, nearest neighbour, break-the-logic, edges) | Lenses without instruments restate what PR bots do; each check here produces something they cannot |
| Scripts to run and parse the review | None — the agent runs it, reads it, applies it | Nothing to maintain as harnesses and models change |
