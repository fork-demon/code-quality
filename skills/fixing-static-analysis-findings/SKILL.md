---
name: fixing-static-analysis-findings
description: >
  How to respond when static analysis (Checkstyle, PMD, linters, the qcheck
  gate) reports findings on your changes. Use whenever a quality gate or hook
  fails, or a lint/analysis report needs to be resolved.
---

# Fixing Static-Analysis Findings

A failing quality gate is a work item, not an obstacle. The goal is to make the
code genuinely better, not to make the message disappear.

## The loop

1. **Read the finding fully** — rule id, file, line, message. Understand what
   the rule protects against before touching code.
2. **Fix the root cause in the code.** The fix that satisfies the rule's intent,
   not the minimum edit that silences it.
3. **Re-run the same check** (the hook or `tools/qcheck.sh`) to confirm the
   finding is gone and no new ones appeared.
4. Repeat until clean. If after **3 cycles** findings remain that you believe
   are wrong or infeasible to fix, stop and report them to the user with your
   reasoning — do not loop forever and do not suppress on your own authority.

## Absolute rules

- **Never edit the gate to pass the gate.** Do not modify ruleset XML,
  thresholds, baseline files, hook configuration, or exclude lists to get a
  pass. Those belong to humans.
- **Never blanket-suppress.** No file-level `@SuppressWarnings`, no
  `// NOPMD` / `CHECKSTYLE:OFF` regions.
- A **narrow suppression** (single line/member, specific rule) is allowed only
  when: the finding is a demonstrable false positive, you add a comment stating
  the concrete justification, and you tell the user you did it.

## Fix playbook for common findings

| Finding family | Right fix |
|---|---|
| Unused import / variable / private method | Delete it. |
| Magic number | Extract a named constant at the narrowest sensible scope. |
| Method too long / cyclomatic complexity | Extract cohesive steps into named private methods; consider whether a responsibility wants its own class. |
| Empty catch block | Handle, or wrap-and-rethrow with context; log only at the layer that owns the decision. |
| Catching Exception/Throwable | Catch the specific types the called code declares. |
| String comparison with `==` | Use `equals`/`Objects.equals`. |
| `equals` without `hashCode` | Implement both (or use a record / generated implementation). |
| System.out / printStackTrace | Use the project logger with a meaningful message and the exception as the last argument. |
| Mutable public field / missing encapsulation | Make it private final; expose behavior, not state. |
| Resource not closed | try-with-resources. |
| Concatenated SQL / command strings | Parameterized query / prepared statement / builder API. |
| Dead code branch | Delete it; git history preserves it. |

## Reporting

When you finish, summarize: findings fixed (count by rule), any narrow
suppressions added with justification, and any findings you are escalating
instead of fixing.
