---
name: writing-good-tests
description: >
  What makes a test trustworthy. Use whenever writing or changing tests, or
  adding behavior (which requires tests). Framework-agnostic; repo-specific
  test conventions (fakes, fixtures, ports) live in the repo, not here.
---

# Writing Good Tests

A test suite exists so anyone can change the code with confidence. Each test
either builds that trust or erodes it.

## What to test

- **Behavior through the public API**, never private internals or interaction
  sequences — those break on every refactor.
- **Every new behavior gets a test in the same change.** Bug fixes start with a
  failing test that reproduces the bug.
- **Edge and error cases are the point**: empty, null/absent, zero, negative,
  boundaries, duplicates. Assert the specific exception type and a useful
  message/state — not just "something threw".

## Structure

- Arrange–Act–Assert, visually separated; one outcome per test.
- Names state scenario and expectation: `rejectsOrderWhenQuantityExceedsStock`.
- **No logic in tests** — no loops, conditionals, or computed expected values
  that mirror the production algorithm. Expected values are literals.
- Independent, order-agnostic, deterministic: inject clocks/ids, no sleeps,
  no network, no shared mutable fixtures. Flaky → quarantine or fix now.

## Test doubles — keep it minimal

- Real objects when fast and deterministic; fakes at boundaries the repo
  already provides (**follow the repo's own conventions** — if it has a
  `testing-conventions.md` or a reference fake, use that pattern); mocks last.
- Never mock the class under test or value objects.
- `verify` only interactions that *are* the behavior ("email sent once");
  verifying every call freezes implementation details.
- One test class per production class is not a requirement; one test per
  *behavior* is.

## Smells that fail review

- Test changed to accept wrong output instead of fixing the code.
- Assertion-free tests, or asserting only "no exception thrown", to lift coverage.
- `@Disabled`/skipped without a linked reason and owner.
- Copy-pasted bodies differing in one literal — use parameterized tests.
- A mock-and-verify test that would pass with the production logic deleted.
