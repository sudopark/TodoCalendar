#!/bin/bash
# log-usage.py 회귀 테스트 — 임시 USAGE_LOG_DIR에 fixture 이벤트를 흘려 기록 검증
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
export USAGE_LOG_DIR="$TMP_DIR"
TODAY=$(date +%Y-%m-%d)
LOG="$TMP_DIR/$TODAY.jsonl"

run_hook() { printf '%s' "$1" | python3 log-usage.py; }
last_line() { tail -1 "$LOG"; }
field() { # json_line key
  printf '%s' "$1" | python3 -c "import json,sys; print(json.load(sys.stdin).get('$2',''))"
}

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fi
}

# --- prompt 기록 ---
run_hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","cwd":"/proj","prompt":"11번 빠르게 시작하자"}'
assert_eq "prompt 이벤트 기록" "prompt" "$(field "$(last_line)" event)"
assert_eq "prompt 본문" "11번 빠르게 시작하자" "$(field "$(last_line)" prompt)"
assert_eq "session_id 기록" "s1" "$(field "$(last_line)" session_id)"

# --- Skill 툴 사용 → 직전 지시 임베드 ---
run_hook '{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/proj","tool_name":"Skill","tool_input":{"skill":"kickoff","args":"659"}}'
assert_eq "skill 이벤트" "skill" "$(field "$(last_line)" event)"
assert_eq "skill 이름" "kickoff" "$(field "$(last_line)" name)"
assert_eq "via tool" "tool" "$(field "$(last_line)" via)"
assert_eq "지시 임베드" "11번 빠르게 시작하자" "$(field "$(last_line)" instruction)"

# --- Task 툴(서브에이전트) 사용 ---
run_hook '{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/proj","tool_name":"Task","tool_input":{"subagent_type":"code-reviewer","description":"관점 리뷰","prompt":"..."}}'
assert_eq "agent 이벤트" "agent" "$(field "$(last_line)" event)"
assert_eq "agent 타입" "code-reviewer" "$(field "$(last_line)" name)"
assert_eq "agent 지시 임베드" "11번 빠르게 시작하자" "$(field "$(last_line)" instruction)"

# --- Agent 툴명도 동일 처리 ---
run_hook '{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/proj","tool_name":"Agent","tool_input":{"subagent_type":"Explore","description":"탐색"}}'
assert_eq "Agent 툴명 지원" "agent" "$(field "$(last_line)" event)"

# --- subagent_type 없으면 general-purpose ---
run_hook '{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/proj","tool_name":"Task","tool_input":{"description":"기본 에이전트"}}'
assert_eq "기본 agent 타입" "general-purpose" "$(field "$(last_line)" name)"

# --- 슬래시 커맨드 → prompt 레코드 + skill 레코드 두 줄 ---
run_hook '{"hook_event_name":"UserPromptSubmit","session_id":"s2","cwd":"/proj","prompt":"/kickoff 659 11번"}'
assert_eq "슬래시 → skill 기록" "skill" "$(field "$(last_line)" event)"
assert_eq "슬래시 스킬명" "kickoff" "$(field "$(last_line)" name)"
assert_eq "via slash" "slash" "$(field "$(last_line)" via)"

# --- 세션 격리: s2 지시가 s1 사용 레코드에 안 섞임 ---
run_hook '{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/proj","tool_name":"Skill","tool_input":{"skill":"commit"}}'
assert_eq "세션별 지시 격리" "11번 빠르게 시작하자" "$(field "$(last_line)" instruction)"

# --- 500자 절단 ---
LONG=$(python3 -c "print('가'*600)")
run_hook "{\"hook_event_name\":\"UserPromptSubmit\",\"session_id\":\"s3\",\"cwd\":\"/proj\",\"prompt\":\"$LONG\"}"
assert_eq "프롬프트 500자 절단" "501" "$(field "$(last_line)" prompt | tr -d '\n' | wc -m | tr -d ' ')"

# --- state 없는 세션의 사용 → instruction 빈 문자열 폴백 ---
run_hook '{"hook_event_name":"PostToolUse","session_id":"s-nostate","cwd":"/proj","tool_name":"Skill","tool_input":{"skill":"plan"}}'
assert_eq "state 부재 시 instruction 폴백" "" "$(field "$(last_line)" instruction)"

# --- 비문자열 tool_input 필드 → str 코어션으로 레코드 유실 없음 ---
run_hook '{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/proj","tool_name":"Skill","tool_input":{"skill":"kickoff","args":{"n":1}}}'
assert_eq "비문자열 args 코어션" "skill" "$(field "$(last_line)" event)"

# --- 무관 툴 무시 ---
BEFORE=$(wc -l < "$LOG" | tr -d ' ')
run_hook '{"hook_event_name":"PostToolUse","session_id":"s1","cwd":"/proj","tool_name":"Read","tool_input":{"file_path":"/foo"}}'
assert_eq "무관 툴 미기록" "$BEFORE" "$(wc -l < "$LOG" | tr -d ' ')"

# --- 운영: prompt 처리 시 로그 디렉토리 700 강제 ---
chmod 755 "$TMP_DIR"
run_hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","cwd":"/proj","prompt":"권한 확인"}'
assert_eq "로그 디렉토리 700" "700" "$(stat -f "%Lp" "$TMP_DIR")"

# --- 운영: 7일 지난 세션 state prune, 최신은 보존 ---
STALE="$TMP_DIR/.sessions/stale-session.json"
printf '{"instruction":"old"}' > "$STALE"
touch -t "$(date -v-8d +%Y%m%d%H%M)" "$STALE"
run_hook '{"hook_event_name":"UserPromptSubmit","session_id":"s1","cwd":"/proj","prompt":"prune 트리거"}'
assert_eq "8일 지난 state 제거" "0" "$(ls "$TMP_DIR/.sessions" | grep -c stale-session)"
assert_eq "최신 state 보존" "1" "$(ls "$TMP_DIR/.sessions" | grep -c '^s1.json$')"

# --- fail-open: 깨진 입력에도 exit 0 ---
printf 'not-json' | python3 log-usage.py
assert_eq "fail-open exit 0 (깨진 JSON)" "0" "$?"
printf '{}' | python3 log-usage.py
assert_eq "fail-open exit 0 (빈 이벤트)" "0" "$?"

echo "---"
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
