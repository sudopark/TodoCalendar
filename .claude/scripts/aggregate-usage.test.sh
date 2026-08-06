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
{"ts":"2026-01-01T09:41:00+09:00","event":"skill","session_id":"s6","name":"implement"}
{"ts":"2026-01-01T09:42:00+09:00","event":"skill","session_id":"s7","name":"implement"}
{"ts":"2026-01-01T09:45:00+09:00","event":"skill_end","session_id":"s1","name":"implement","compliance":"full","deviations":[]}
{"ts":"2026-01-01T09:47:00+09:00","event":"skill_end","session_id":"s1","name":"implement","compliance":"full","deviations":[]}
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
{"ts":"2026-01-02T09:00:00+09:00","event":"axis_leak","session_id":"s5","missed_axis":1,"finding":"f1","pr":""}
{"ts":"2026-01-02T09:01:00+09:00","event":"axis_leak","session_id":"s5","missed_axis":1,"finding":"f2","pr":""}
{"ts":"2026-01-02T09:02:00+09:00","event":"axis_leak","session_id":"s5","missed_axis":1,"finding":"f3","pr":"705"}
{"ts":"2026-01-02T09:03:00+09:00","event":"axis_leak","session_id":"s5","missed_axis":2,"finding":"g1","pr":""}
{"ts":"2026-01-02T09:04:00+09:00","event":"axis_leak","session_id":"s5","missed_axis":2,"finding":"g2","pr":""}
{"ts":"2026-01-01T15:00:00+09:00","event":"skill","session_id":"s10","name":"superpowers:writing-skills"}
{"ts":"2026-01-01T15:01:00+09:00","event":"skill_end","session_id":"s10","name":"superpowers:writing-skills","compliance":"partial","deviations":[{"clause":"a","reason":"b"}]}
{"ts":"2026-01-01T15:02:00+09:00","event":"skill_end","session_id":"s11","name":"superpowers:writing-skills","compliance":"partial","deviations":[{"clause":"a","reason":"b"}]}
{"ts":"2026-01-01T15:03:00+09:00","event":"skill_end","session_id":"s12","name":"superpowers:writing-skills","compliance":"partial","deviations":[{"clause":"a","reason":"b"}]}
{"ts":"2026-01-01T15:04:00+09:00","event":"correction","session_id":"s10","skills":["superpowers:writing-skills"],"summary":"c1","gist":""}
{"ts":"2026-01-01T15:05:00+09:00","event":"correction","session_id":"s11","skills":["superpowers:writing-skills"],"summary":"c2","gist":""}
{"ts":"2026-01-01T15:06:00+09:00","event":"correction","session_id":"s12","skills":["superpowers:writing-skills"],"summary":"c3","gist":""}
{"ts":"2026-01-01T16:00:00+09:00","event":"skill","session_id":"t1","name":"superpowers:brainstorming"}
{"ts":"2026-01-01T16:01:00+09:00","event":"skill","session_id":"t2","name":"superpowers:brainstorming"}
{"ts":"2026-01-01T16:02:00+09:00","event":"skill","session_id":"t3","name":"superpowers:brainstorming"}
{"ts":"2026-01-01T16:03:00+09:00","event":"skill","session_id":"t4","name":"superpowers:brainstorming"}
{"ts":"2026-01-01T16:04:00+09:00","event":"skill","session_id":"t5","name":"superpowers:brainstorming"}
{"ts":"2026-01-01T16:05:00+09:00","event":"skill_end","session_id":"t1","name":"superpowers:brainstorming","compliance":"full","deviations":[]}
{"ts":"2026-01-01T16:06:00+09:00","event":"skill_end","session_id":"t2","name":"superpowers:brainstorming","compliance":"full","deviations":[]}
{"ts":"2026-01-01T17:00:00+09:00","event":"skill","session_id":"u1","name":"handoff-prepare"}
{"ts":"2026-01-01T17:01:00+09:00","event":"skill","session_id":"u2","name":"handoff-prepare"}
{"ts":"2026-01-01T17:02:00+09:00","event":"skill","session_id":"u3","name":"handoff-prepare"}
{"ts":"2026-01-01T17:03:00+09:00","event":"skill","session_id":"u4","name":"handoff-prepare"}
{"ts":"2026-01-01T17:04:00+09:00","event":"skill","session_id":"u5","name":"handoff-prepare"}
{"ts":"2026-01-01T17:05:00+09:00","event":"correction","session_id":"u1","skills":["handoff-prepare"],"summary":"c1","gist":""}
{"ts":"2026-01-01T17:06:00+09:00","event":"correction","session_id":"u2","skills":["handoff-prepare"],"summary":"c2","gist":""}
{"ts":"2026-01-01T17:07:00+09:00","event":"correction","session_id":"u3","skills":["handoff-prepare"],"summary":"c3","gist":""}
JSONL

OUT=$(python3 aggregate-usage.py)

# implement: 발동 레코드 7·종료 레코드 3이지만 세션 dedupe → 발동 5(s1·s2·s3·s6·s7)·종료 2(s1·s2)
#            → 누락률 60% ≥ 50% (min 5 충족) → 초과
assert_contains "누락률 초과 검출" "implement" "$OUT"
assert_contains "누락률 수치" "60%" "$OUT"
assert_contains "세션 단위 dedupe 카운트" "발동 5·종료 2" "$OUT"
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

# --- 플러그인 스킬(plugin_prefixes 매칭): 조항 개정 경로가 없어 준수 축만 제외 ---
# superpowers:writing-skills — partial 3·correction 3이어도 violations 미노출
assert_eq "플러그인 partial·correction 임계 제외" "0" "$(printf '%s' "$OUT" | grep -c "superpowers:writing-skills")"
# superpowers:brainstorming — 누락률은 기록 배선(프로젝트 스킬 소관) 신호라 유지
assert_contains "플러그인 누락률은 유지" "superpowers:brainstorming — 종료 레코드 누락률 60%" "$OUT"
# 제외된 버킷도 --all 진단 표에는 남는다
assert_contains "--all에 플러그인 버킷" "superpowers:writing-skills" "$ALL"

# --- excluded_skills: 이 레포가 정본을 안 가져 정비 경로가 없는 대상은 임계 판정 통째 제외 ---
# handoff-prepare — 발동 5·종료 0(누락률 100%)·correction 3이어도 violations 미노출
assert_eq "excluded_skills 임계 판정 전체 제외" "0" "$(printf '%s' "$OUT" | grep -c "handoff-prepare")"
# 제외해도 --all 진단 표에는 남는다
assert_contains "--all에 excluded_skills 버킷" "handoff-prepare" "$ALL"

# --- 축별 누수 집계 ---
# 축1: 3건 ≥ 임계 3 → 초과, 축2: 2건 < 임계 3 → 미검출, 축3: 0건
assert_contains "축1 누수 임계 초과 검출" "축1 누수 3건 (임계 3)" "$OUT"
assert_eq "축2 누수 임계 미만 미검출" "0" "$(printf '%s' "$OUT" | grep -c "축2 누수")"
assert_eq "축3 누수 없음 미검출" "0" "$(printf '%s' "$OUT" | grep -c "축3 누수")"

assert_contains "--all 축별 누수 라인" "축별 누수 — 축1 3 · 축2 2 · 축3 0" "$ALL"

# --- improvement axis:1 마킹(누수 이후 ts) → 축1 소비돼 라인 사라짐 ---
cat >> "$FIXTURE" << 'JSONL'
{"ts":"2026-01-02T10:00:00+09:00","event":"improvement","session_id":"s5","name":"axis:1"}
JSONL
OUT_AFTER_MARK=$(python3 aggregate-usage.py)
assert_eq "axis:1 마킹 이후 축1 라인 소비" "0" "$(printf '%s' "$OUT_AFTER_MARK" | grep -c "축1 누수")"

# 초과 없음 → 무출력
ONLY_OK="$TMP_DIR/only-ok"
mkdir "$ONLY_OK"
printf '%s\n' '{"ts":"2026-01-01T09:00:00+09:00","event":"skill","session_id":"s1","name":"plan"}' '{"ts":"2026-01-01T09:01:00+09:00","event":"skill_end","session_id":"s1","name":"plan","compliance":"full","deviations":[]}' > "$ONLY_OK/2026-01-01.jsonl"
QUIET=$(USAGE_LOG_DIR="$ONLY_OK" python3 aggregate-usage.py)
RC=$?
assert_eq "초과 없음 무출력" "" "$QUIET"
assert_eq "exit 0 고정" "0" "$RC"

# 누수 없는 fixture --all → "축별 누수" 라인 미출력
ALL_ONLY_OK=$(USAGE_LOG_DIR="$ONLY_OK" python3 aggregate-usage.py --all)
assert_eq "누수 없으면 --all에 축별 누수 라인 미출력" "0" "$(printf '%s' "$ALL_ONLY_OK" | grep -c "축별 누수")"

echo "---"
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
