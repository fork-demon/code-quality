---
name: design-patterns
description: >
  Choosing and applying design patterns without over-engineering. Use when
  designing new components/modules, refactoring tangled code, or when deciding
  HOW to structure a solution — before writing the implementation.
---

# Design Patterns — applied, not collected

Patterns are vocabulary for solutions to recurring forces. The skill is knowing
**when the forces are actually present** — a pattern applied without its forces
is over-engineering.

## Decision guide: symptom → pattern

| Symptom in the code | Consider | Not before |
|---|---|---|
| `switch`/`if-else` chains on a type code repeated in several places | Polymorphism / Strategy | The chain exists in ONE place — a single switch is fine |
| Construction of an object needs many optional parts / telescoping constructors | Builder | The object has ≤3 constructor args |
| Callers must not know which concrete implementation they get | Factory method / DI container | There is only one implementation |
| An operation must vary independently from the object structure it walks | Visitor | Structure is small and stable — plain methods are clearer |
| Several objects must react when one changes | Observer / events | One known reactor — call it directly |
| An interface you don't own doesn't fit the one you need | Adapter | You own both sides — change one instead |
| Expensive/slow object should be created only when used, or access controlled | Proxy / lazy | No measured cost |
| A family of steps with an invariant skeleton and varying details | Template method or Strategy (prefer composition) | Steps don't actually vary |
| Undo, audit trail, or queued operations needed | Command | You just need a function call |
| One object's state machine has behavior differing per state | State | Two states — a boolean and an `if` is clearer |

## Anti-patterns to actively avoid

- **God class / manager / util dumping grounds** — `XxxManager`, `XxxUtil`,
  `XxxHelper` accreting unrelated behavior. Split by responsibility.
- **Anemic domain model** — data classes with all logic in "service" procedures.
  Put behavior with the data it operates on.
- **Layered lasagna for its own sake** — a pass-through layer that only delegates
  adds cost without value. Every layer must transform, decide, or isolate.
- **Interface-implementation pairs by reflex** (`Foo` + `FooImpl` with one
  implementation, no test seam needed). Add the interface when a second
  implementation or a boundary appears.
- **Singleton for shared state** — hides dependencies and breaks testability.
  Inject the instance instead.
- **Inheritance for code reuse** — leads to fragile hierarchies. Prefer
  composition; inherit only for true is-a substitutability (LSP).

## Process

1. **State the forces first.** Before naming a pattern, write one sentence: what
   varies, what must stay stable, who must not know what.
2. **Pick the simplest structure that resolves those forces.** Often that is a
   function, a map, or polymorphism — not a named pattern.
3. **Name the pattern in code only when it aids the reader** (`OrderValidator`
   beats `OrderValidationStrategyFactoryImpl`).
4. When refactoring toward a pattern, do it in small steps with tests green
   between steps.
