#!/usr/bin/env bash
#
# qcheck — simple Checkstyle + PMD gate for Java files.
#
#   tools/qcheck.sh [file.java ...]
#
# With no arguments, checks the Java files changed in the git working tree
# (vs HEAD, plus staged and untracked). Exits 0 when clean, 1 when findings
# exceed the configured budget, 2 on execution errors.
#
# Configuration: tools/config/qcheck.conf (key=value). Scanner jars are
# downloaded once into ~/.qcheck/tools (override with QCHECK_HOME).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"
QCHECK_HOME="${QCHECK_HOME:-$HOME/.qcheck/tools}"

# ---------- config (defaults, overridden by qcheck.conf) ----------
CHECKSTYLE_ENABLED=true
PMD_ENABLED=true
CHECKSTYLE_VERSION=10.21.1
PMD_VERSION=7.10.0
CHECKSTYLE_RULESET="$CONFIG_DIR/checkstyle.xml"
PMD_RULESET="$CONFIG_DIR/pmd.xml"
MAX_VIOLATIONS=0        # gate fails when total findings exceed this

CONF_FILE="$CONFIG_DIR/qcheck.conf"
if [[ -f "$CONF_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONF_FILE"
fi

log()  { echo "qcheck: $*" >&2; }
die()  { log "ERROR: $*"; exit 2; }

command -v java >/dev/null 2>&1 || die "java not found — install a JDK/JRE 11+"

# ---------- select files ----------
declare -a FILES=()
if [[ $# -gt 0 ]]; then
  for f in "$@"; do [[ "$f" == *.java ]] && FILES+=("$f"); done
else
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r f; do
      [[ "$f" == *.java && -f "$f" ]] && FILES+=("$f")
    done < <( { git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null || true; \
                git ls-files --others --exclude-standard; } | sort -u )
  else
    die "not inside a git repository and no files given"
  fi
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  log "no Java files to check — pass"
  exit 0
fi
log "checking ${#FILES[@]} Java file(s)"

# ---------- fetch tools (once) ----------
mkdir -p "$QCHECK_HOME"
fetch() { # url dest
  [[ -f "$2" ]] && return 0
  log "downloading $(basename "$2") ..."
  curl -fsSL --retry 2 -o "$2.part" "$1" || die "download failed: $1"
  mv "$2.part" "$2"
}

CHECKSTYLE_JAR="$QCHECK_HOME/checkstyle-$CHECKSTYLE_VERSION-all.jar"
PMD_ZIP="$QCHECK_HOME/pmd-dist-$PMD_VERSION-bin.zip"
PMD_BIN="$QCHECK_HOME/pmd-bin-$PMD_VERSION/bin/pmd"

if [[ "$CHECKSTYLE_ENABLED" == "true" ]]; then
  fetch "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-$CHECKSTYLE_VERSION/checkstyle-$CHECKSTYLE_VERSION-all.jar" "$CHECKSTYLE_JAR"
fi
if [[ "$PMD_ENABLED" == "true" && ! -x "$PMD_BIN" ]]; then
  fetch "https://github.com/pmd/pmd/releases/download/pmd_releases%2F$PMD_VERSION/pmd-dist-$PMD_VERSION-bin.zip" "$PMD_ZIP"
  command -v unzip >/dev/null 2>&1 || die "unzip not found (needed to extract PMD)"
  unzip -oq "$PMD_ZIP" -d "$QCHECK_HOME"
  chmod +x "$PMD_BIN"
fi

# ---------- run scanners ----------
TMP_OUT="$(mktemp -t qcheck)"
trap 'rm -f "$TMP_OUT" "$TMP_OUT.pmd" "$TMP_OUT.files"' EXIT
TOTAL=0

if [[ "$CHECKSTYLE_ENABLED" == "true" ]]; then
  # Plain formatter lines: [SEVERITY] /abs/file.java:line:col: message [Rule]
  java -jar "$CHECKSTYLE_JAR" -c "$CHECKSTYLE_RULESET" "${FILES[@]}" >"$TMP_OUT" 2>/dev/null || true
  CS_COUNT=$(grep -c '^\[\(ERROR\|WARN\)\]' "$TMP_OUT" || true)
  if [[ "$CS_COUNT" -gt 0 ]]; then
    echo "── checkstyle ($CS_COUNT) ─────────────────────────────"
    grep '^\[\(ERROR\|WARN\)\]' "$TMP_OUT" | sed "s|$PWD/||"
  fi
  TOTAL=$((TOTAL + CS_COUNT))
fi

if [[ "$PMD_ENABLED" == "true" ]]; then
  printf '%s\n' "${FILES[@]}" > "$TMP_OUT.files"
  "$PMD_BIN" check --file-list "$TMP_OUT.files" -R "$PMD_RULESET" \
      -f text --no-cache --no-progress >"$TMP_OUT.pmd" 2>/dev/null || true
  PMD_COUNT=$(grep -c ':[0-9]*:' "$TMP_OUT.pmd" || true)
  if [[ "$PMD_COUNT" -gt 0 ]]; then
    echo "── pmd ($PMD_COUNT) ───────────────────────────────────"
    grep ':[0-9]*:' "$TMP_OUT.pmd" | sed "s|$PWD/||"
  fi
  TOTAL=$((TOTAL + PMD_COUNT))
fi

# ---------- verdict ----------
echo "───────────────────────────────────────────────────────"
if [[ "$TOTAL" -gt "$MAX_VIOLATIONS" ]]; then
  echo "qcheck: FAIL — $TOTAL finding(s), budget $MAX_VIOLATIONS"
  exit 1
fi
echo "qcheck: PASS — $TOTAL finding(s) within budget $MAX_VIOLATIONS"
exit 0
