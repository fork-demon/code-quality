#!/usr/bin/env bash
#
# Agent hook: run the qcheck gate after each agent iteration and block the
# agent from finishing while findings remain.
#
#   after-iteration.sh [--format claude|tabnine]
#
# Reads the hook event JSON on stdin (unused — the gate always checks the git
# working tree) and emits the agent-specific blocking JSON on stdout.
#   claude  : {"decision":"block","reason":"..."}   (Stop / PostToolUse hooks)
#   tabnine : {"decision":"deny","reason":"..."}    (AfterAgent / AfterTool hooks)
# Exit code is always 0; the JSON carries the decision.

set -uo pipefail

FORMAT="claude"
[[ "${1:-}" == "--format" ]] && FORMAT="${2:-claude}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QCHECK="$SCRIPT_DIR/../tools/qcheck.sh"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${TABNINE_PROJECT_DIR:-$PWD}}"

cat >/dev/null || true   # drain stdin

cd "$PROJECT_DIR" || exit 0

OUTPUT="$(bash "$QCHECK" 2>&1)"
STATUS=$?

if [[ $STATUS -eq 0 ]]; then
  exit 0   # gate passed — no decision needed, agent proceeds
fi

if [[ $STATUS -eq 2 ]]; then
  # Execution error (java missing, download failed). Don't block the agent on
  # infrastructure problems — surface a warning instead.
  echo "qcheck gate could not run: $OUTPUT" >&2
  exit 0
fi

REASON="The code-quality gate failed. Fix these findings (root-cause fixes per the fixing-static-analysis-findings skill — do NOT edit rulesets, budgets, or add suppressions), then finish:

$OUTPUT"

DECISION="block"
[[ "$FORMAT" == "tabnine" ]] && DECISION="deny"

if command -v jq >/dev/null 2>&1; then
  jq -cn --arg d "$DECISION" --arg r "$REASON" '{decision: $d, reason: $r}'
else
  # minimal JSON escaping fallback
  ESCAPED=$(printf '%s' "$REASON" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
  printf '{"decision":"%s","reason":"%s"}\n' "$DECISION" "$ESCAPED"
fi
exit 0
