# Questions people will ask, and answers

Read this once before the session. The answers are short on purpose. Where the honest answer is "we do not know yet", it says so.

A few concepts to have in your head first, because half the questions come back to them:

- **Context window.** Everything the model can see at once: the system prompt, the skills that are loaded, the files it has read, the conversation so far. It is finite, and everything in it costs tokens on every turn. Big context makes the model slower, more expensive and a bit less sharp.
- **Skills.** Markdown files the agent loads when they are relevant. Only a one-line description of each skill sits in the context all the time. The full text is loaded when the agent decides it applies or when you ask for it by name.
- **Subagent.** A separate run of the model with its own fresh context window, its own instructions and its own tool permissions. It cannot see the main conversation. It returns a result to the main agent when it finishes.
- **Hooks.** Small commands the harness runs at fixed moments, for example when the developer sends a prompt or when the agent says it is done. They are ordinary shell commands, so they are deterministic, unlike anything the model does.
- **Non-determinism.** Ask a model the same question twice and you get two slightly different answers. Anything built on a model is a judgement, not a rule. That is why the deterministic parts (the build, the hooks, CI) stay in charge of the hard gates.

---

## Why this approach

**Q: Why do we need this at all? We already have Sonar, Checkstyle, Snyk, tests and PR review bots.**
Those tools find what is wrong: a rule broken, a vulnerability, a failing test. None of them can tell you that a change is three times bigger than it needs to be, that it reinvented a helper that already exists two packages over, or that its tests would pass with the logic deleted. Those are judgement calls, and a rushed reviewer waves them through. Code generated quickly fails in exactly those ways.

**Q: Have we actually seen these problems in our own PRs, or is this a theory?**
Honest answer: the demo is a planted example. The first step of the proposal is to run the review on twenty or thirty PRs we have already merged and compare the findings with what human reviewers actually commented. If it finds nothing that reviewers cared about, we stop. That is why it is framed as an experiment.

**Q: Why four questions? Why not a proper checklist?**
Because checklists are what the linters already are, and the model already knows every generic best practice. The four questions are the ones an experienced reviewer asks that cannot be turned into a rule. Each has one concrete check attached so the answer is evidence, not a vibe. Adding more questions is easy; each one needs a check that produces something a linter cannot, or it is just words.

**Q: What is the "minimal twin" in one sentence?**
A second, independent, smallest-possible implementation of the same task, built by a separate agent that never sees the real change, so we have something concrete to compare the real change against.

**Q: Why does the twin have to be built without seeing the change?**
If the same model reads the change and then writes "a smaller version", it copies the shape of what it just read. The comparison becomes worthless. Giving the twin builder only the brief and the base code is what makes it an independent measurement. It is the same reason you ask two people to estimate separately before comparing.

**Q: How does the twin builder know what to build if it cannot see the change?**
It gets the brief as Given / When / Then scenarios: what must be true afterwards, never how. Those come from feature files if the team has them, otherwise from the prompts the developer typed (the harness records them per branch), confirmed by the developer with one question. The format cannot describe a class or a pattern, so nothing about the solution leaks through.

**Q: Isn't a smaller implementation just worse code sometimes?**
Yes, if "smaller" meant fewest characters. It does not. The twin builder is told to use the repo's own style, reuse existing utilities, and follow the same quality rules as the main agent. Smaller is the yardstick, not the standard. The review keeps a "keep list" for things that are bigger than the twin for a real reason, and a twin that is small by being clever gets fixed.

---

## Alternatives, and why not those

**Q: Why not just put all of this in AGENTS.md or CLAUDE.md?**
Those files are loaded into every conversation, on every turn, whether relevant or not. They are the right place for short, always-true facts about a repo: how to build, how to run tests, naming conventions. A review procedure with four checks is several hundred lines and only matters at review time. Putting it there taxes every prompt with tokens it does not need and makes the file nobody reads even longer. Skills load on demand; that is the whole reason they exist.

**Q: Why not just a better system prompt?**
Same answer. A system prompt is always on. The rules that are always on here are tiny (about sixty lines in `code-quality-core`). The expensive parts, the twin and the four checks, only load when a review runs.

**Q: Why not do this in CI with the PR review agent we already have?**
Maybe later, if the experiment earns it: one paragraph added to the PR agent's prompt would make it the enforcement point. Today the pack runs only in Tabnine, on the developer's machine. CI is late. The developer has moved on, the context is gone, and fixing means a second round trip. Running the same questions before the push, inside the agent that just wrote the code, is where fixes are cheapest. Both places, same questions.

**Q: Why not the multi-agent reviewer from the first version, with four parallel reviewers?**
That is what most PR bots already are: several personas reading the same diff and listing opinions. What was missing was an instrument. A "design reviewer" persona says "this looks over-engineered"; the twin says "it is 7.8 times its minimal size, and here are the seven things you can delete with nothing breaking". Each of the four questions now has that kind of check.

**Q: Why not write a script to do the measuring? It would be deterministic.**
The first version had scripts, rulesets and a runner, and the review rightly said it would drift from the build and become a second thing to maintain. Everything here is markdown the agent reads. The only shell in the pack is two one-line hooks, and one of them just runs our own `gradle check`. When the models change, we edit a paragraph, not a parser.

**Q: Why not an off-the-shelf tool that does this?**
If you know one that builds an independent minimal implementation and measures against it, please say so; I looked and did not find one. The other three checks are ordinary review practice made explicit. The point of doing it as prompts is that it costs almost nothing to try and almost nothing to delete.

---

## Design choices

**Q: Why one subagent and not several?**
Because only one of the four checks needs isolation. The twin must be built without seeing the change, so it gets its own context. The other three checks work best with the change in front of them, so the main agent does them. More subagents would mean more tokens and more coordination for no extra independence.

**Q: Why not make the whole review a subagent?**
Then it could not talk to the developer, and two of the checks depend on that: confirming the brief ("is this what you asked for?") and offering to apply the findings. It also would not have the conversation, which is often the best record of what was asked.

**Q: Why record the developer's prompts? Is that surveillance?**
It is a per-branch text file inside `.git`, never committed, never leaves the machine, and you can delete it. Its only job is to give the review a truthful brief when nobody wrote one down, which is most of the time. Developers are not asked to be more organised; the harness remembers for them.

**Q: What if the developer wrote code by hand in the IDE, outside the agent?**
The diff contains it regardless, so it is measured like everything else. The only thing the prompt log might miss is a behaviour nobody typed a prompt for, and the review checks the change for behaviour no record mentions and asks about it before building the twin.

**Q: What if a team does not write feature files?**
Then the brief comes from the prompt log or the conversation. Feature files are the best source, not a requirement. Teams that have them get a stronger twin for free.

**Q: Why hooks at all, given the reviewer objected to the agent-loop gate?**
The objection was to running our own static analysis after every iteration. These hooks are different in both ways: they run once per turn, not per tool call, and the build hook runs the repo's own `gradle check`, nothing of ours. It does exactly what the review asked for: feed the build's findings back to the agent.

**Q: Can the agent cheat the review, for example by editing the ruleset so the build passes?**
The skills forbid it and the review checks for it, but a rule in a prompt is advice, not a lock. The real lock is CI: a required check that fails when gate files change without a label. That already exists in the plan and costs a few lines in a workflow we already run.

---

## Cost and tokens

**Q: How many tokens does a review cost?**
Rough shape, for a typical small change: the main agent reads the diff and the skill (a few thousand tokens), the twin builder reads the relevant base code and writes the twin in its own context (tens of thousands, depending on how much it has to read), and the three other checks read neighbouring code and run tests (a few thousand more). Call it tens of thousands of tokens per review, a few minutes of wall time, and well under a dollar at current prices for most changes. Measure it in the calibration run; the number should go on the slide once we have it.

**Q: Does the always-on skill make every prompt more expensive?**
Barely. What sits in every conversation is a one-line description per skill, a few dozen tokens each. The full `code-quality-core` text (about sixty lines) loads when the agent is writing code, which is when you want it. The review skill loads only during a review.

**Q: Is the twin worth its cost on a five-line change?**
Probably not, and the review should say so and skip it. The ratio matters on changes big enough to hide unnecessary code. A sensible rule of thumb is to run the full review before pushing, not after every edit. The `/done` command is designed for that moment.

**Q: What about the time? Developers will not wait five minutes.**
They wait for CI already, and that is longer. This runs once, before the push, while they are reading the summary. If it turns out to be too slow in practice, the fix is to run only the twin on large changes and the other three checks on everything.

---

## Reliability

**Q: The model is non-deterministic. How can this be a gate?**
It is not a hard gate on its own, and the deck says so. The blocking rules are few and coarse (a ratio above 3, a behaviour with no real test, edits to the gate) and everything else is advisory. Anything that must be exact stays in the build and in CI, which are deterministic. Think of it as a senior reviewer who is fast and never tired, not as a linter.

**Q: What if the twin builder cheats by dropping a requirement to look smaller?**
The main agent checks the twin against the brief and sends it back if a scenario is missing. If a real behaviour surfaces later that the brief did not have, the brief is extended, the twin is extended, and the ratio is recounted. The ratio is an estimate with a stated source, not a court verdict.

**Q: What stops the brief from leaking the implementation?**
The format. Given / When / Then describes what happens, not what classes exist. Whoever writes the brief, the twin builder cannot receive "add a validator and a builder" because those words are not scenarios.

**Q: What happens if the tests cannot run, or there is no similar code to compare with?**
Each check has a fallback: read and judge, and say the check was not executed. The review does not fail because a tool was missing; it tells you which answers are weaker.

**Q: How do we know it keeps working after a model upgrade?**
The calibration set of real PRs is the regression test. Re-run it after any model change and compare the ratios and findings with the previous run. That is cheaper than a synthetic eval and it uses our own code.

---

## Rollout

**Q: What do developers have to do differently?**
Type `/done` when they think they are finished, and answer one question ("is this what you asked for?"). Everything else is automatic. The always-on skill nudges the agent while it writes; most people will not notice it.

**Q: Does the agent commit the code? Who writes the commit message?**
The agent never commits or pushes on its own. At the end of `/done` it shows a ready-made commit message (one line of summary, the acceptance criteria, the ratio before and after) and asks "commit with this message?". Say yes and it commits; say no and you commit yourself and can paste the message. The developer stays in control, and either way the criteria and the ratio end up on the commit.

**Q: Where does the PR description come into it?**
Only through the commit. GitHub pre-fills the PR description from the commit body when a branch has one commit; otherwise the developer pastes it. Nothing in this pack talks to GitHub or CI. It runs in Tabnine on the developer's machine, before the push.

**Q: What if people just skip `/done`?**
Some will, and for an experiment that is fine. The commit and the PR will not carry the brief and the ratio, so the skip is visible to whoever reviews it. If the experiment earns a standard, the PR review agent we already run can be told, in one added paragraph, to run the review itself when the block is missing. That is a later decision, not part of this proposal.

**Q: How do we know if it worked?**
Median ratio of merged PRs, and the number of fit and test findings, tracked for a quarter. If the numbers move, add the CI paragraph and call it a standard. If they do not, delete the pack. It is three hundred lines of markdown; deleting it costs nothing.

**Q: What is the maintenance cost?**
Three skill files, one subagent file, two command files, one settings snippet. No scripts, no rulesets, no runner. When Tabnine or the model changes, the most likely edit is a paragraph in a skill.

**Q: Does this work with Claude Code or Gemini CLI too?**
Yes. Skills are the same format. Commands and the subagent definition translate one to one; the demo repo has the Claude Code version ready.

**Q: What would make you drop the idea?**
If the calibration run shows the findings do not match what our reviewers actually care about, or if the ratio is noisy enough between runs that nobody trusts it. Either result would show up in the first two weeks.
