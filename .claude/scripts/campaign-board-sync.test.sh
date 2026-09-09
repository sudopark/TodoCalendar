#!/bin/bash
# campaign-board-sync.sh 회귀 테스트 — 스풀 부재 no-op·부분 복사·전체 복사·렌더·재게시 지시 부재·실패 비차단 검증
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
echo "- 09-09 20:00 activity" > "$REPO/.operations/500/activity.md"
echo "plan only" > "$REPO/docs/operations/501/campaign.md"

BOARD="$TMP_DIR/board"

# 1. 스풀 루트 부재 → no-op exit 0, 아무것도 안 만든다
OUT=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>/dev/null; echo "rc=$?")
assert_eq "spool_absent_noop_exit0" "rc=0" "$OUT"
assert_no_file "spool_absent_creates_nothing" "$BOARD"

# 2. 전체 복사 — 5파일 모두
mkdir -p "$BOARD/state"
RC=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>/dev/null; echo $?)
assert_eq "all_files_exit0" "0" "$RC"
assert_file "all_copied_campaign" "$BOARD/state/500/campaign.md"
assert_file "all_copied_ledger" "$BOARD/state/500/campaign-progress.md"
assert_file "all_copied_opord" "$BOARD/state/500/opord.md"
assert_file "all_copied_progress" "$BOARD/state/500/progress.md"
assert_file "all_copied_activity" "$BOARD/state/500/activity.md"

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

# 5. 렌더 호출 — render.py 가 있으면 sync 가 함께 돌린다
cat > "$BOARD/render.py" <<'PY'
import pathlib, sys
pathlib.Path(pathlib.Path(__file__).parent / "board.html").write_text("rendered")
PY
CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 >/dev/null 2>&1
assert_file "render_invoked" "$BOARD/board.html"
assert_eq "render_output" "rendered" "$(cat "$BOARD/board.html")"

# 6. 재게시 지시 없음 — Artifact 재게시는 수동이라(#1070) URL 파일이 있어도 stdout 은 조용하다
echo "https://claude.ai/code/artifact/abc" > "$BOARD/artifact-url.txt"
OUT=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>/dev/null)
assert_eq "url_no_directive" "" "$OUT"

# 7. 렌더 실패 → 비차단(exit 0), stderr 로만 남긴다
echo "STALE" > "$BOARD/board.html"
echo "import sys; sys.exit(1)" > "$BOARD/render.py"
OUT=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>/dev/null)
ERR=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>&1 >/dev/null)
RC=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 >/dev/null 2>&1; echo $?)
assert_eq "render_failure_exit0" "0" "$RC"
assert_eq "render_failure_silent_stdout" "" "$OUT"
assert_eq "render_failure_keeps_stale_file" "STALE" "$(cat "$BOARD/board.html")"
case "$ERR" in *"렌더 실패"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "FAIL: render_failure_stderr — [$ERR]";; esac

# 8. render.py 부재 → stdout 조용, 크래시 없음
rm "$BOARD/render.py"
OUT=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 500 2>/dev/null)
assert_eq "no_renderer_silent_stdout" "" "$OUT"
rm "$BOARD/artifact-url.txt" "$BOARD/board.html"

# 9. 인자 없음 → exit 0 + stderr 안내
ERR=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh 2>&1 >/dev/null; true)
RC=$(CAMPAIGN_BOARD_DIR="$BOARD" REPO_ROOT="$REPO" bash campaign-board-sync.sh >/dev/null 2>&1; echo $?)
assert_eq "no_arg_exit0" "0" "$RC"
case "$ERR" in *"이슈번호"*) PASS=$((PASS+1));; *) FAIL=$((FAIL+1)); echo "FAIL: no_arg_stderr_message — [$ERR]";; esac

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
