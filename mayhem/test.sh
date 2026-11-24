#!/usr/bin/env bash
#
# mayhem/test.sh — runs olive's own unit tests (built by mayhem/build.sh into build-tests/):
# upstream tests/ (timeline, general; compositing has no enabled tests) and ext/core's tests
# (rational, timecode, timerange, stringutils). Each test case prints a PASSED line; a binary
# passes only with exit 0 AND every expected case reporting PASSED (counts pinned below).
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}


# Headless Qt, and a writable cache for the OCIO config the app tests extract.
export QT_QPA_PLATFORM=offscreen
SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/olive-test.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
export XDG_CACHE_HOME="$SCRATCH/cache" XDG_CONFIG_HOME="$SCRATCH/config" XDG_DATA_HOME="$SCRATCH/data" XDG_RUNTIME_DIR="$SCRATCH"

B="$SRC/build-tests"
# binary : number of test cases it runs (each must print a "PASSED" line)
SUITE=(
  "ext/core/rational-test:5"
  "ext/core/timecode-test:2"
  "ext/core/timerange-test:2"
  "ext/core/stringutils-test:1"
  "tests/timeline/timeline-tests:7"
  "tests/general/common-tests:1"
)
passed=0; failed=0
for entry in "${SUITE[@]}"; do
  bin="${entry%%:*}"; want="${entry##*:}"
  if [ ! -x "$B/$bin" ]; then
    echo "MISSING test binary $B/$bin (mayhem/build.sh should have built it)" >&2
    failed=$(( failed + want )); continue
  fi
  out="$(cd "$SCRATCH" && "$B/$bin" 2>&1)"; rc=$?
  echo "$out" | grep -E 'PASSED|FAIL' || true
  got=$(printf '%s\n' "$out" | grep -cE '(::|-) PASSED$' || true)
  [ "$got" -gt "$want" ] && got=$want
  if [ "$rc" -ne 0 ] || [ "$got" -lt "$want" ]; then
    echo "FAIL: $bin rc=$rc passed=$got/$want" >&2
    [ "$got" -eq "$want" ] && got=$(( want - 1 ))
  fi
  passed=$(( passed + got )); failed=$(( failed + want - got ))
done

emit_ctrf "olive-unit-tests" "$passed" "$failed" 0
