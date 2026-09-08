#!/bin/bash
# 캠페인 상황판 스풀 sync — 계획·진행 파일을 레포 밖 스풀로 복사한다.
# 부수 작업이라 어떤 실패도 본 절차를 막지 않는다 (항상 exit 0, stderr 로만 남긴다).
ISSUE="$1"
BOARD="${CAMPAIGN_BOARD_DIR:-$HOME/.claude/campaign-board}"
REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"

[ -z "$ISSUE" ] && { echo "campaign-board-sync: 이슈번호가 없다" >&2; exit 0; }
[ -d "$BOARD/state" ] || exit 0   # 상황판을 안 쓰는 환경 — 조용히 no-op

DEST="$BOARD/state/$ISSUE"
mkdir -p "$DEST" 2>/dev/null || { echo "campaign-board-sync: $DEST 생성 실패" >&2; exit 0; }

for SRC in "$REPO/docs/operations/$ISSUE/campaign.md" \
           "$REPO/docs/operations/$ISSUE"/opord*.md \
           "$REPO/.operations/$ISSUE/campaign-progress.md" \
           "$REPO/.operations/$ISSUE/progress.md"; do
  [ -f "$SRC" ] || continue
  cp "$SRC" "$DEST/" 2>/dev/null || echo "campaign-board-sync: 복사 실패 — $SRC" >&2
done
exit 0
