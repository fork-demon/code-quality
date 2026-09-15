# Recorded minimal-twin review

_Real, unedited output of a coding agent (Claude Code CLI, default model, no subagents, ~4 minutes) running the `minimal-twin-review` skill on `demo/verbose-change` applied to `demo/sample-app`. Running `/quality-review` on that branch in Tabnine reproduces it._

## Minimal Twin Review — `verbose` vs `main`

**Note on verification:** this sandbox has no network access to Maven Central (Gradle resolution returns 403 through the proxy), so I could not run `gradle test` for either the twin or the real diff. I verified both by `javac`-compiling the main sources (both compile) and by manually tracing execution paths for correctness/test claims below.

```
Verdict: pass-with-majors
Task: Reject an order whose total quantity exceeds 100, before any stock is checked/reserved (from commit 15cbf14).
Twin: +47 lines, 2 declarations        Actual: +368 lines, ~35 declarations
Verbosity ratio: 7.8x   Removable: ~300 lines
```

**Twin** (`/tmp/twin`, built from `main` before re-reading the real diff in depth): add a `MAX_TOTAL_QUANTITY = 100` constant and one `OrderLimitExceededException`, check `order.totalQuantity() > MAX_TOTAL_QUANTITY` as the first line of `place()`, throw before the existing stock loop. 3 new tests: at-limit (passes), over-limit across a single line, over-limit across multiple lines (total, not per-line).

### Delete list (nothing breaks, or only the scaffolding's own test)
- `OrderValidator` interface + `DefaultOrderValidator` — interface with a single implementation and no second implementation or test seam; inline the check into `OrderService`. Nothing breaks.
- `OrderServiceConfig` + `Builder` — config knob for a value with one caller, no test needs it configurable. Deleting also removes `testConfigBuilder` (its own test). Delete both.
- `OrderValidationHelper` — three one-line static wrappers (`calculateTotalQuantity`, `exceedsLimit`, `hasSufficientStock`), each with one caller. Deleting also removes `testHelperExceedsLimit`. Delete both.
- `OrderPlacementResult` + the `place()` return-type change (`void`→`OrderPlacementResult`) — textbook result-wrapper for a method that can just return/throw; not required by the task. Only its own assertions (`result.isSuccess()`, `result.getOrder()`) break — rewrite those to just call `place(order)`.
- `LOGGER` field + all `LOGGER.log(...)` calls + the `catch (...) { log; throw; }` in `place()` — logging at every branch, catch-log-rethrow adds no information. Nothing breaks if removed.
- `validateOrder()` / `checkStock()` / `reserveStock()` private method extraction — each has exactly one caller and only delegates; inlining changes nothing observable.
- Second `OrderService(Inventory, OrderServiceConfig)` constructor — falls away once `OrderServiceConfig` is deleted.

### Keep list
- The total-quantity check itself and `OrderLimitExceededException` — this is the task.
- `testPlaceOrderExceedsLimit`, `testPlaceOrderInsufficientStock`, `testPlaceOrderEmpty` — pin real behavior the twin also needs.

### Tests
- **Untested boundary**: no test for total quantity exactly `100` (must succeed). The twin has one; the real diff doesn't.
- **`testValidateOrderNull` passes for the wrong reason**: `place()` calls `LOGGER.log(..., order.customerId())` as its *first* statement, so a null `order` throws `NullPointerException` there — before `validateOrder()`'s explicit `if (order == null) throw new IllegalArgumentException(...)` is ever reached. That check (duplicated again in `DefaultOrderValidator.validate()`) is dead code, and the test pins the accidental NPE, not the intended `IllegalArgumentException`. If the dead check were ever fixed to actually run first, this test would break. This is a real correctness defect, not just style.
- **Switched the repo's own fake for Mockito mocks** in most tests (`FakeInventory` is explicitly commented as "the reference fake for this repo," per the tests skill's rule to follow the repo's existing fake convention) and added `verify(...)`/`verifyNoMoreInteractions(...)` call-sequence assertions the original state-based tests didn't need — freezes implementation details for no behavioral gain.
- Test names regressed from scenario-stating (`reservesEveryLineWhenStockSuffices`) to generic (`testPlaceOrderSuccess`).

### Security
- `order.customerId()` (external input) is written unsanitized into log messages at INFO/WARNING via string formatting/concatenation — enables log forging (CRLF injection) if a customer ID can contain control characters, and logs data that may be considered personal/identifying, both new attack surface introduced solely by logging that the task didn't ask for.

**Offer:** I can apply the delete list (revert `OrderService`/tests to the twin's minimal shape, keep the total-quantity check, add the missing at-limit test, fix or drop the dead null check) and then re-run the repo's build/checkstyle/pmd — say the word and I'll do it. Note the build/test run will need network access to Maven Central that this sandbox currently blocks.
