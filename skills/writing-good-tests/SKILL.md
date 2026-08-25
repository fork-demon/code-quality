---
name: writing-good-tests
description: >
  Test best practices — what to test, how to structure tests, and what makes a
  test trustworthy. Use whenever writing or modifying tests, adding new
  behavior (which requires tests), or reviewing test code.
---

# Writing Good Tests

A test suite's job is to let anyone change the code confidently. Every test you
write either builds that trust or erodes it.

## What to test

- **Behavior, not implementation.** Test through the public API of the unit;
  asserting on private internals or interaction sequences makes refactoring
  break tests that should pass.
- **Every new behavior gets a test in the same change.** Code without a test is
  not done. Bug fixes start with a failing test that reproduces the bug.
- **Edge cases are the point.** Empty collections, null/absent optionals, zero,
  negative, boundary sizes, duplicates, unicode, concurrent access where
  relevant. The happy path alone tests almost nothing.
- **Error paths.** Assert the specific exception type and that the message/state
  is useful — not just "something threw".

## Structure

- **Arrange–Act–Assert**, visually separated. One logical assertion focus per
  test — multiple `assert` lines are fine when they verify one outcome.
- **Names state the scenario and expectation:**
  `rejectsOrderWhenQuantityExceedsStock`, not `testOrder2`.
- **No logic in tests.** No loops, conditionals, or computation of expected
  values that mirror the production algorithm. Expected values are literals a
  reviewer can verify by eye.
- **Independent and order-agnostic.** Each test builds its own state; shared
  mutable fixtures cause flakiness and hidden coupling.
- **Deterministic.** No real clocks, sleeps, network, or randomness — inject
  clocks/ids, use fakes, control time explicitly. A flaky test is worse than no
  test: quarantine-or-fix immediately.

## Test doubles

- Prefer **fakes** (in-memory implementations) over mocks for anything with
  behavior; prefer real objects when they are fast and deterministic.
- Mock only at architectural boundaries you own the contract for (external
  services, repositories). Never mock the class under test or value objects.
- Over-specified mocks (`verify` on every interaction) freeze implementation
  details — verify only interactions that ARE the behavior (e.g. "email was
  sent once").

## Levels

- **Unit tests** carry the bulk: fast, no I/O, run on every iteration.
- **Integration tests** cover the wiring: one per boundary (DB mapping, HTTP
  serialization, queue consumption), not one per business case.
- **End-to-end** only for a few critical journeys.
- Coverage: aim to cover the behavior you can articulate, not a percentage.
  Never write assertion-free tests to raise a coverage number — that is
  falsifying the safety signal.

## Smells that fail review

- Test changed to accept wrong output instead of fixing the code.
- `@Disabled`/skipped tests without a linked reason and owner.
- Asserting only "no exception thrown".
- Sleeping to "wait" for async work instead of awaiting a condition.
- Copy-pasted test bodies differing in one literal — use parameterized tests.
