#!/bin/bash
# aggregate-usage.py 회귀 테스트 — fixture JSONL로 집계·임계 판정 검증
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
export USAGE_LOG_DIR="$TMP_DIR"

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fi
}
assert_contains() { # desc substring text
  case "$3" in *"$2"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  missing: [$2]"; echo "  in: [$3]";; esac
}

FIXTURE="$TMP_DIR/2026-01-01.jsonl"
cat > "$FIXTURE" << 'JSONL'
{"ts":"2026-01-01T09:00:00+09:00","event":"skill","session_id":"s1","name":"implement"}
{"ts":"2026-01-01T09:10:00+09:00","event":"skill","session_id":"s1","name":"implement"}
{"ts":"2026-01-01T09:20:00+09:00","event":"skill","session_id":"s2","name":"implement"}
{"ts":"2026-01-01T09:30:00+09:00","event":"skill","session_id":"s2","name":"implement"}
{"ts":"2026-01-01T09:40:00+09:00","event":"skill","session_id":"s3","name":"implement"}
{"ts":"2026-01-01T09:45:00+09:00","event":"skill_end","session_id":"s1","name":"implement","compliance":"full","deviations":[]}
{"ts":"2026-01-01T09:50:00+09:00","event":"skill_end","session_id":"s2","name":"implement","compliance":"full","deviations":[]}
{"ts":"2026-01-01T10:00:00+09:00","event":"skill","session_id":"s1","name":"pr"}
{"ts":"2026-01-01T10:01:00+09:00","event":"correction","session_id":"s1","skills":["pr"],"summary":"c1","gist":""}
{"ts":"2026-01-01T10:02:00+09:00","event":"correction","session_id":"s1","skills":["pr"],"summary":"c2","gist":""}
{"ts":"2026-01-01T10:03:00+09:00","event":"correction","session_id":"s2","skills":["pr"],"summary":"c3","gist":""}
{"ts":"2026-01-01T11:00:00+09:00","event":"skill","session_id":"s1","name":"commit"}
{"ts":"2026-01-01T11:01:00+09:00","event":"skill_end","session_id":"s1","name":"commit","compliance":"partial","deviations":[{"clause":"a","reason":"b"}]}
{"ts":"2026-01-01T11:02:00+09:00","event":"skill_end","session_id":"s2","name":"commit","compliance":"partial","deviations":[{"clause":"a","reason":"b"}]}
{"ts":"2026-01-01T11:03:00+09:00","event":"skill_end","session_id":"s3","name":"commit","compliance":"partial","deviations":[{"clause":"a","reason":"b"}]}
{"ts":"2026-01-01T12:00:00+09:00","event":"correction","session_id":"s9","skills":[],"summary":"미귀속 교정","gist":""}
{"ts":"2026-01-01T12:01:00+09:00","event":"correction","session_id":"s9","skills":[],"summary":"미귀속 교정2","gist":""}
{"ts":"2026-01-01T12:02:00+09:00","event":"correction","session_id":"s9","skills":[],"summary":"미귀속 교정3","gist":""}
{"ts":"2026-01-01T13:00:00+09:00","event":"skill","session_id":"s4","name":"kickoff"}
{"ts":"2026-01-01T13:01:00+09:00","event":"correction","session_id":"s4","skills":["kickoff"],"summary":"c1","gist":""}
{"ts":"2026-01-01T13:02:00+09:00","event":"correction","session_id":"s4","skills":["kickoff"],"summary":"c2","gist":""}
{"ts":"2026-01-01T13:03:00+09:00","event":"correction","session_id":"s4","skills":["kickoff"],"summary":"c3","gist":""}
{"ts":"2026-01-01T14:00:00+09:00","event":"improvement","session_id":"s4","name":"kickoff"}
JSONL

OUT=$(python3 aggregate-usage.py)

# implement: 발동 5·종료 2 → 누락률 60% ≥ 50% (min 5 충족) → 초과
assert_contains "누락률 초과 검출" "implement" "$OUT"
assert_contains "누락률 수치" "60%" "$OUT"
# pr: correction 3건 ≥ 3 → 초과
assert_contains "correction 임계 검출" "pr — correction 3건" "$OUT"
# commit: partial 3건 ≥ 3 → 초과 (발동 1이라 누락률 판정은 제외돼야 함)
assert_contains "partial 임계 검출" "commit — 준수 partial 3건" "$OUT"
# kickoff: correction 3건이지만 improvement 마킹(14:00) 이후 레코드 없음 → 미검출
BEFORE_KICKOFF=$(printf '%s' "$OUT" | grep -c "kickoff")
assert_eq "improvement 마킹 이후만 집계" "0" "$BEFORE_KICKOFF"
# 미귀속 correction 3건 ≥ 3이어도 violations 제외(소비 경로 없음) — --all 표에만 노출
assert_eq "미귀속 violations 제외" "0" "$(printf '%s' "$OUT" | grep -c "미귀속")"
ALL=$(python3 aggregate-usage.py --all)
assert_contains "--all에 미귀속 버킷" "(미귀속)" "$ALL"
assert_contains "--all에 스킬별 카운트" "implement" "$ALL"

# 초과 없음 → 무출력
ONLY_OK="$TMP_DIR/only-ok"
mkdir "$ONLY_OK"
printf '%s\n' '{"ts":"2026-01-01T09:00:00+09:00","event":"skill","session_id":"s1","name":"plan"}' '{"ts":"2026-01-01T09:01:00+09:00","event":"skill_end","session_id":"s1","name":"plan","compliance":"full","deviations":[]}' > "$ONLY_OK/2026-01-01.jsonl"
QUIET=$(USAGE_LOG_DIR="$ONLY_OK" python3 aggregate-usage.py)
RC=$?
assert_eq "초과 없음 무출력" "" "$QUIET"
assert_eq "exit 0 고정" "0" "$RC"

echo "---"
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
