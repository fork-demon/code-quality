#!/usr/bin/env bash
#
# qcheck — simple Checkstyle + PMD gate for Java files, with optional
# Snyk (SAST + dependency vulns) and SonarQube quality-gate checks.
#
#   tools/qcheck.sh [file.java ...]
#
# With no arguments, checks the Java files changed in the git working tree
# (vs HEAD, plus staged and untracked). Exits 0 when clean, 1 when findings
# exceed the configured budget, 2 on execution errors.
#
# Snyk and Sonar are OFF by default: they scan the whole project (not just
# changed files), need their own auth/server, and are too slow for an
# after-every-iteration hook. Enable them in qcheck.conf for pre-commit/CI
# or on-demand /quality-gate runs.
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

SNYK_ENABLED=false            # snyk code test (SAST) — needs `snyk auth` once
SNYK_DEPS_ENABLED=false       # snyk test (dependency vulnerabilities)
SNYK_SEVERITY_THRESHOLD=low   # low | medium | high | critical
SONAR_ENABLED=false           # sonar-scanner + server-side quality gate

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
  # Snyk/Sonar scan the whole project, so they still run (a build.gradle
  # change can introduce a vulnerable dependency with zero .java files
  # touched).
  if [[ "$SNYK_ENABLED" != "true" && "$SNYK_DEPS_ENABLED" != "true" && "$SONAR_ENABLED" != "true" ]]; then
    log "no Java files to check — pass"
    exit 0
  fi
  CHECKSTYLE_ENABLED=false
  PMD_ENABLED=false
  log "no changed Java files — running project-level scanners only"
else
  log "checking ${#FILES[@]} Java file(s)"
fi

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
trap 'rm -f "$TMP_OUT" "$TMP_OUT.pmd" "$TMP_OUT.files" "$TMP_OUT.snyk" "$TMP_OUT.snykdeps" "$TMP_OUT.sonar"' EXIT
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

# Snyk: whole-project scans via the snyk CLI. Exit codes: 0 clean, 1 issues,
# 2 error, 3 no supported files. Findings are the "✗ ..." lines.
if [[ "$SNYK_ENABLED" == "true" || "$SNYK_DEPS_ENABLED" == "true" ]]; then
  command -v snyk >/dev/null 2>&1 \
    || die "snyk CLI not found — install it and run 'snyk auth' once"
fi

if [[ "$SNYK_ENABLED" == "true" ]]; then
  SNYK_STATUS=0
  snyk code test --severity-threshold="$SNYK_SEVERITY_THRESHOLD" \
      >"$TMP_OUT.snyk" 2>&1 || SNYK_STATUS=$?
  case $SNYK_STATUS in
    0) : ;;
    1)
      SNYK_COUNT=$(grep -c '✗' "$TMP_OUT.snyk" || true)
      [[ "$SNYK_COUNT" -eq 0 ]] && SNYK_COUNT=1
      echo "── snyk code ($SNYK_COUNT) ────────────────────────────"
      grep -A2 '✗' "$TMP_OUT.snyk" | sed "s|$PWD/||"
      TOTAL=$((TOTAL + SNYK_COUNT))
      ;;
    3) log "snyk code: no supported files — skipped" ;;
    *) die "snyk code test failed to run: $(tail -n 3 "$TMP_OUT.snyk")" ;;
  esac
fi

if [[ "$SNYK_DEPS_ENABLED" == "true" ]]; then
  SNYK_STATUS=0
  snyk test --severity-threshold="$SNYK_SEVERITY_THRESHOLD" \
      >"$TMP_OUT.snykdeps" 2>&1 || SNYK_STATUS=$?
  case $SNYK_STATUS in
    0) : ;;
    1)
      DEPS_COUNT=$(grep -c '✗' "$TMP_OUT.snykdeps" || true)
      [[ "$DEPS_COUNT" -eq 0 ]] && DEPS_COUNT=1
      echo "── snyk dependencies ($DEPS_COUNT) ────────────────────"
      grep '✗' "$TMP_OUT.snykdeps"
      TOTAL=$((TOTAL + DEPS_COUNT))
      ;;
    3) log "snyk deps: no supported manifest — skipped" ;;
    *) die "snyk test failed to run: $(tail -n 3 "$TMP_OUT.snykdeps")" ;;
  esac
fi

# Sonar: run the scanner and wait for the SERVER-side quality gate verdict
# (-Dsonar.qualitygate.wait=true makes sonar-scanner exit non-zero when the
# project's quality gate fails). Project settings come from
# sonar-project.properties or SONAR_* variables in qcheck.conf/environment.
if [[ "$SONAR_ENABLED" == "true" ]]; then
  command -v sonar-scanner >/dev/null 2>&1 \
    || die "sonar-scanner not found — install the SonarScanner CLI"
  [[ -n "${SONAR_HOST_URL:-}" && -n "${SONAR_TOKEN:-}" ]] \
    || die "SONAR_HOST_URL and SONAR_TOKEN must be set for the sonar check"
  SONAR_STATUS=0
  sonar-scanner -Dsonar.qualitygate.wait=true \
      ${SONAR_PROJECT_KEY:+-Dsonar.projectKey="$SONAR_PROJECT_KEY"} \
      >"$TMP_OUT.sonar" 2>&1 || SONAR_STATUS=$?
  if [[ $SONAR_STATUS -ne 0 ]]; then
    if grep -qi 'QUALITY GATE STATUS: FAILED' "$TMP_OUT.sonar"; then
      echo "── sonar (quality gate FAILED) ────────────────────────"
      grep -iE 'quality gate|condition' "$TMP_OUT.sonar" | sed 's/^[^ ]* *//'
      log "full report on the Sonar server (see dashboard link above)"
      TOTAL=$((TOTAL + 1))
    else
      die "sonar-scanner failed to run: $(tail -n 5 "$TMP_OUT.sonar")"
    fi
  fi
fi

# ---------- verdict ----------
echo "───────────────────────────────────────────────────────"
if [[ "$TOTAL" -gt "$MAX_VIOLATIONS" ]]; then
  echo "qcheck: FAIL — $TOTAL finding(s), budget $MAX_VIOLATIONS"
  exit 1
fi
echo "qcheck: PASS — $TOTAL finding(s) within budget $MAX_VIOLATIONS"
exit 0
