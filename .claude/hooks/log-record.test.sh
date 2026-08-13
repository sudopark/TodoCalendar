#!/bin/bash
# log-record.py 회귀 테스트 — 임시 USAGE_LOG_DIR에 CLI 호출을 흘려 기록 검증
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
export USAGE_LOG_DIR="$TMP_DIR"
export CLAUDE_CODE_SESSION_ID="env-session"
TODAY=$(date +%Y-%m-%d)
LOG="$TMP_DIR/$TODAY.jsonl"

last_line() { tail -1 "$LOG"; }
field() { # json_line key — 스칼라 값
  printf '%s' "$1" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$2',''))"
}
field_json() { # json_line key — 배열·객체 값을 JSON 문자열로
  printf '%s' "$1" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('$2'), ensure_ascii=False))"
}
assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fi
}

# --- skill_end full ---
python3 log-record.py skill_end --name implement --compliance full
assert_eq "skill_end 이벤트" "skill_end" "$(field "$(last_line)" event)"
assert_eq "skill_end 이름" "implement" "$(field "$(last_line)" name)"
assert_eq "compliance full" "full" "$(field "$(last_line)" compliance)"
assert_eq "full의 deviations 빈 배열" "[]" "$(field_json "$(last_line)" deviations)"
assert_eq "session env 폴백" "env-session" "$(field "$(last_line)" session_id)"

# --- skill_end partial + deviation 파싱 (게이트 통과) ---
python3 log-record.py skill_end --name implement --compliance partial --deviation-reviewed \
  --deviation "리팩터 게이트 생략::1파일 단순 수정" --deviation "스킴 계산 생략::테스트 無 경로"
DEVS=$(field_json "$(last_line)" deviations)
assert_eq "deviation 2건" "2" "$(printf '%s' "$DEVS" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")"
assert_eq "clause 파싱" "리팩터 게이트 생략" "$(printf '%s' "$DEVS" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['clause'])")"
assert_eq "reason 파싱" "1파일 단순 수정" "$(printf '%s' "$DEVS" | python3 -c "import json,sys; print(json.load(sys.stdin)[0]['reason'])")"

# --- partial인데 deviation 없음 → exit 2 + 미기록 ---
BEFORE=$(wc -l < "$LOG" | tr -d ' ')
python3 log-record.py skill_end --name implement --compliance partial 2>/dev/null
assert_eq "partial deviation 누락 exit 2" "2" "$?"
assert_eq "partial deviation 누락 미기록" "$BEFORE" "$(wc -l < "$LOG" | tr -d ' ')"

# --- partial인데 --deviation-reviewed 없음 → 게이트 exit 2 + 미기록 ---
BEFORE_GATE=$(wc -l < "$LOG" | tr -d ' ')
GATE_ERR=$(python3 log-record.py skill_end --name kickoff --compliance partial \
  --deviation "A-3 플랜 생략::4조건 충족" 2>&1)
assert_eq "게이트 미통과 exit 2" "2" "$?"
assert_eq "게이트 미통과 미기록" "$BEFORE_GATE" "$(wc -l < "$LOG" | tr -d ' ')"
case "$GATE_ERR" in
  *"A-3 플랜 생략 :: 4조건 충족"*) PASS=$((PASS+1)) ;;
  *) FAIL=$((FAIL+1)); echo "FAIL: 게이트 안내에 이탈 목록 노출"; echo "  actual: [$GATE_ERR]" ;;
esac
case "$GATE_ERR" in
  *"--deviation-reviewed"*) PASS=$((PASS+1)) ;;
  *) FAIL=$((FAIL+1)); echo "FAIL: 게이트 안내에 재호출 방법 노출"; echo "  actual: [$GATE_ERR]" ;;
esac

# --- full은 게이트 없이 그대로 기록 ---
python3 log-record.py skill_end --name kickoff --compliance full
assert_eq "full은 게이트 무관 기록" "full" "$(field "$(last_line)" compliance)"

# --- correction 귀속 스킬 리스트 ---
python3 log-record.py correction --skills "implement, pr" --summary "stub에 검증 넣지 말라" --gist "stub에서 assert 하지마"
assert_eq "correction 이벤트" "correction" "$(field "$(last_line)" event)"
assert_eq "skills 파싱" '["implement", "pr"]' "$(field_json "$(last_line)" skills)"
assert_eq "summary 기록" "stub에 검증 넣지 말라" "$(field "$(last_line)" summary)"

# --- correction 미귀속 (skills 생략) → 빈 배열 ---
python3 log-record.py correction --summary "귀속 스킬 없는 교정"
assert_eq "미귀속 skills 빈 배열" "[]" "$(field_json "$(last_line)" skills)"

# --- correction summary 누락 → exit 2 ---
python3 log-record.py correction --skills implement 2>/dev/null
assert_eq "correction summary 누락 exit 2" "2" "$?"

# --- improvement 마킹 ---
python3 log-record.py improvement --name kickoff
assert_eq "improvement 이벤트" "improvement" "$(field "$(last_line)" event)"
assert_eq "improvement 이름" "kickoff" "$(field "$(last_line)" name)"

# --- --session 인자가 env보다 우선 ---
python3 log-record.py skill_end --name plan --compliance full --session "arg-session"
assert_eq "--session 우선" "arg-session" "$(field "$(last_line)" session_id)"

# --- axis_leak 정상 기록 ---
python3 log-record.py axis_leak --missed-axis 3 --finding "RED 단계에서 반복 종료조건 케이스 누락"
assert_eq "axis_leak 이벤트" "axis_leak" "$(field "$(last_line)" event)"
assert_eq "axis_leak missed_axis" "3" "$(field "$(last_line)" missed_axis)"
assert_eq "axis_leak finding" "RED 단계에서 반복 종료조건 케이스 누락" "$(field "$(last_line)" finding)"
assert_eq "axis_leak pr 생략 시 빈 문자열" "" "$(field "$(last_line)" pr)"

# --- axis_leak --pr 포함 ---
python3 log-record.py axis_leak --missed-axis 1 --finding "명세 표현 누락" --pr 705
assert_eq "axis_leak pr 기록" "705" "$(field "$(last_line)" pr)"

# --- axis_leak --finding 누락 → exit 2 + 미기록 ---
BEFORE_AXIS=$(wc -l < "$LOG" | tr -d ' ')
python3 log-record.py axis_leak --missed-axis 2 2>/dev/null
assert_eq "axis_leak finding 누락 exit 2" "2" "$?"
assert_eq "axis_leak finding 누락 미기록" "$BEFORE_AXIS" "$(wc -l < "$LOG" | tr -d ' ')"

# --- axis_leak --missed-axis 범위 밖(4) → argparse 거부 exit 2 ---
python3 log-record.py axis_leak --missed-axis 4 --finding "범위밖" 2>/dev/null
assert_eq "axis_leak missed-axis 범위밖 exit 2" "2" "$?"

echo "---"
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
