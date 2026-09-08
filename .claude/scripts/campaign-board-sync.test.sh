#!/bin/bash
# campaign-board-sync.sh 회귀 테스트 — 스풀 부재 no-op·부분 복사·전체 복사·실패 비차단 검증
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: [$2] actual: [$3]"; fi
}
assert_file() { # desc path
  if [ -f "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 — 없음: $2"; fi
}
assert_no_file() { # desc path
  if [ ! -e "$2" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 — 존재: $2"; fi
}

# 가짜 레포 구성
REPO="$TMP_DIR/repo"
mkdir -p "$REPO/docs/operations/500" "$REPO/.operations/500" "$REPO/docs/operations/501"
echo "campaign" > "$REPO/docs/operations/500/campaign.md"
echo "ledger" > "$REPO/.operations/500/campaign-progress.md"
echo "opord" > "$REPO/docs/operations/500/opord.md"
echo "progress" > "$REPO/.operations/500/progress.md"
echo "plan only" > "$REPO/docs/operations/501/campaign.md"

BOARD="$TMP_DIR/board"

# 1. 스풀 루트 부재 → no-op exit 0, 아무것도 안 만든다
OUT=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>/dev/null; echo "rc=$?")
assert_eq "spool_absent_noop_exit0" "rc=0" "$OUT"
assert_no_file "spool_absent_creates_nothing" "$BOARD"

# 2. 전체 복사 — 4파일 모두
mkdir -p "$BOARD/state"
RC=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>/dev/null; echo $?)
assert_eq "all_files_exit0" "0" "$RC"
assert_file "all_copied_campaign" "$BOARD/state/500/campaign.md"
assert_file "all_copied_ledger" "$BOARD/state/500/campaign-progress.md"
assert_file "all_copied_opord" "$BOARD/state/500/opord.md"
assert_file "all_copied_progress" "$BOARD/state/500/progress.md"

# 3. 부분 복사 — 계획만 있는 이슈는 있는 것만
RC=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 501 2>/dev/null; echo $?)
assert_eq "partial_exit0" "0" "$RC"
assert_file "partial_copied_campaign" "$BOARD/state/501/campaign.md"
assert_no_file "partial_no_ledger" "$BOARD/state/501/campaign-progress.md"

# 4. 실패도 exit 0 — 미생성 이슈 디렉토리 + 읽기 전용 스풀 루트로 mkdir 실패를 실제 유발
mkdir -p "$REPO/docs/operations/503"
echo "campaign" > "$REPO/docs/operations/503/campaign.md"
chmod -w "$BOARD/state"
ERR=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 503 2>&1 >/dev/null)
RC=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 503 >/dev/null 2>&1; echo $?)
chmod +w "$BOARD/state"
assert_eq "failure_still_exit0" "0" "$RC"
assert_no_file "failure_creates_nothing" "$BOARD/state/503"
case "$ERR" in *"생성 실패"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "FAIL: failure_stderr_message — [$ERR]";; esac

# 5. 인자 없음 → exit 0 + stderr 안내
ERR=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 2>&1 >/dev/null; true)
RC=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh >/dev/null 2>&1; echo $?)
assert_eq "no_arg_exit0" "0" "$RC"
case "$ERR" in *"이슈번호"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "FAIL: no_arg_stderr_message — [$ERR]";; esac

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
