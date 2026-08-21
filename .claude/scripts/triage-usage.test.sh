#!/bin/bash
# triage-usage.py 회귀 테스트 — fixture JSONL·기록 파일로 오탐 판정 검증
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
export USAGE_LOG_DIR="$TMP_DIR"

assert_contains() { # desc substring text
  case "$3" in *"$2"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  missing: [$2]"; echo "  in: [$3]";; esac
}
assert_not_contains() { # desc substring text
  case "$3" in *"$2"*) FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  unexpected: [$2]"; echo "  in: [$3]";; *) PASS=$((PASS+1));; esac
}
verdict_of() { # bucket kind json
  python3 -c "
import json,sys
data=json.load(sys.stdin)
for item in data:
    if item['bucket']==sys.argv[1] and item['kind']==sys.argv[2]:
        print(item['verdict']); break
else:
    print('(none)')
" "$1" "$2" <<< "$3"
}

FIXTURE="$TMP_DIR/2026-01-01.jsonl"
cat > "$FIXTURE" << 'JSONL'
{"ts":"2026-01-01T09:00:00+09:00","event":"correction","session_id":"s1","skills":["pr"],"summary":"첫째","gist":"g1"}
{"ts":"2026-01-01T09:01:00+09:00","event":"correction","session_id":"s2","skills":["pr"],"summary":"둘째","gist":"g2"}
{"ts":"2026-01-01T09:02:00+09:00","event":"correction","session_id":"s3","skills":["pr"],"summary":"셋째","gist":"g3"}
{"ts":"2026-01-01T09:03:00+09:00","event":"correction","session_id":"s4","skills":["commit"],"summary":"넷째","gist":"g4"}
{"ts":"2026-01-01T09:04:00+09:00","event":"correction","session_id":"s5","skills":["commit"],"summary":"다섯째","gist":"g5"}
{"ts":"2026-01-01T09:05:00+09:00","event":"correction","session_id":"s6","skills":["commit"],"summary":"여섯째","gist":"g6"}
JSONL

# --- 임계 초과 신호가 항목으로 잡힌다
OUT=$(python3 triage-usage.py --json --skills-root "$TMP_DIR/skills-missing")
assert_contains "pr correction 이 항목에 잡힌다" '"bucket": "pr"' "$OUT"
assert_contains "commit correction 이 항목에 잡힌다" '"bucket": "commit"' "$OUT"

# --- 기여 레코드가 그대로 실린다 (판단을 기억이 아니라 데이터로)
assert_contains "기여 레코드 summary 가 실린다" '첫째' "$OUT"
assert_contains "기여 레코드 gist 가 실린다" 'g6' "$OUT"

# --- 스킬 조항이 최신 기여 레코드보다 나중에 개정됐으면 stale (마킹만 하면 되는 오탐)
# 정비 시점은 파일 mtime(체크아웃 시각)이 아니라 git 커밋 시각으로 판정한다
SKILLS="$TMP_DIR/skills"
mkdir -p "$SKILLS/pr" "$SKILLS/commit"
git -C "$SKILLS" init -q
git -C "$SKILLS" config user.email t@t; git -C "$SKILLS" config user.name t
echo "x" > "$SKILLS/pr/SKILL.md"
echo "x" > "$SKILLS/commit/SKILL.md"
git -C "$SKILLS" add -A
GIT_AUTHOR_DATE="2025-12-31T00:00:00+09:00" GIT_COMMITTER_DATE="2025-12-31T00:00:00+09:00" \
  git -C "$SKILLS" commit -q -m base
echo "y" >> "$SKILLS/pr/SKILL.md"                 # pr 만 기여 레코드보다 나중에 개정
git -C "$SKILLS" add -A
GIT_AUTHOR_DATE="2026-02-01T00:00:00+09:00" GIT_COMMITTER_DATE="2026-02-01T00:00:00+09:00" \
  git -C "$SKILLS" commit -q -m revise
OUT=$(python3 triage-usage.py --json --skills-root "$SKILLS")
assert_contains "정비가 나중에 들어간 스킬은 stale" "stale" "$(verdict_of pr correction "$OUT")"
assert_contains "정비가 없던 스킬은 actionable" "actionable" "$(verdict_of commit correction "$OUT")"

# --- 이미 기록된 신호는 duplicate (재보고 금지)
RECORDED="$TMP_DIR/recorded.md"
echo '<!-- signal: commit/correction -->' > "$RECORDED"
OUT=$(python3 triage-usage.py --json --skills-root "$SKILLS" --recorded-file "$RECORDED")
assert_contains "이슈에 이미 있는 신호는 duplicate" "duplicate" "$(verdict_of commit correction "$OUT")"

# --- 사람이 읽는 출력에는 actionable 만 뜬다
OUT=$(python3 triage-usage.py --skills-root "$SKILLS")
assert_contains "actionable 은 보고된다" "commit" "$OUT"
assert_not_contains "stale 은 보고되지 않는다" "⚠️ pr —" "$OUT"
assert_contains "stale 은 상태 정리 명령으로 안내된다" "improvement --name pr" "$OUT"

# --- 신호가 없으면 무출력
rm -f "$FIXTURE"
OUT=$(python3 triage-usage.py --skills-root "$SKILLS")
assert_contains "신호 없으면 빈 출력" "" "$OUT"
[ -z "$OUT" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL: 신호 없으면 무출력"; }

# --- partial 신호도 요지가 실린다 (deviations 폴백)
PFIX="$TMP_DIR/2026-01-02.jsonl"
cat > "$PFIX" << 'JSONL'
{"ts":"2026-01-02T09:00:00+09:00","event":"skill_end","session_id":"p1","name":"commit","compliance":"partial","deviations":[{"clause":"흡수 절차","reason":"별도 커밋으로 남김"}]}
{"ts":"2026-01-02T09:01:00+09:00","event":"skill_end","session_id":"p2","name":"commit","compliance":"partial","deviations":[{"clause":"스테이징","reason":"유저가 직접 add"}]}
{"ts":"2026-01-02T09:02:00+09:00","event":"skill_end","session_id":"p3","name":"commit","compliance":"partial","deviations":[{"clause":"메시지 컨벤션","reason":"핫픽스 예외"}]}
JSONL
OUT=$(python3 triage-usage.py --skills-root "$SKILLS")
assert_contains "partial 도 임계로 잡힌다" "준수 partial" "$OUT"
assert_contains "partial 요지가 조항::사유로 실린다" "흡수 절차::별도 커밋으로 남김" "$OUT"
assert_contains "partial 도 signal 키를 그대로 출력한다" "signal: commit/partial" "$OUT"
rm -f "$PFIX"

# --- missing_rate 는 기여 레코드가 없어 stale 이 성립하지 않는다 (구조적 예외 고정)
MFIX="$TMP_DIR/2026-01-03.jsonl"
{ for i in 1 2 3 4 5; do
    echo "{\"ts\":\"2026-01-03T09:0$i:00+09:00\",\"event\":\"skill\",\"session_id\":\"m$i\",\"name\":\"pr\"}"
  done; } > "$MFIX"
OUT=$(python3 triage-usage.py --json --skills-root "$SKILLS")
assert_contains "pr 조항이 나중에 개정됐어도 missing_rate 는 actionable" \
  "actionable" "$(verdict_of pr missing_rate "$OUT")"
OUT=$(python3 triage-usage.py --skills-root "$SKILLS")
assert_contains "missing_rate 도 signal 키를 그대로 출력한다" "signal: pr/missing_rate" "$OUT"
rm -f "$MFIX"

# --- 축 누수는 implement 가 다른 사유로 개정돼도 stale 로 뒤집히지 않는다
mkdir -p "$SKILLS/implement"
echo "x" > "$SKILLS/implement/SKILL.md"
git -C "$SKILLS" add -A
GIT_AUTHOR_DATE="2026-03-01T00:00:00+09:00" GIT_COMMITTER_DATE="2026-03-01T00:00:00+09:00" \
  git -C "$SKILLS" commit -q -m implement-touch
AFIX="$TMP_DIR/2026-01-04.jsonl"
cat > "$AFIX" << 'JSONL'
{"ts":"2026-01-04T09:00:00+09:00","event":"axis_leak","session_id":"a1","missed_axis":1,"finding":"가드 지워도 초록"}
{"ts":"2026-01-04T09:01:00+09:00","event":"axis_leak","session_id":"a2","missed_axis":1,"finding":"형제 TC 미이식"}
{"ts":"2026-01-04T09:02:00+09:00","event":"axis_leak","session_id":"a3","missed_axis":1,"finding":"제거분 미검증"}
JSONL
OUT=$(python3 triage-usage.py --json --skills-root "$SKILLS")
assert_contains "축 누수는 implement 개정에도 actionable 유지" \
  "actionable" "$(verdict_of axis:1 leak "$OUT")"
OUT=$(python3 triage-usage.py --skills-root "$SKILLS")
assert_contains "축 누수 finding 이 요지로 실린다" "가드 지워도 초록" "$OUT"
rm -f "$AFIX"

echo "---"
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
