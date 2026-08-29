#!/usr/bin/env bash
# 개발 대시보드(Project #2) 아이템 상태 배선.
#   사용: .claude/scripts/project-board.sh <issue-number> <status>
#   예:   .claude/scripts/project-board.sh 768 "In Progress"
#
# 보드에 없는 이슈는 추가하면서 상태를 설정한다 (item-add 는 멱등).
set -euo pipefail

OWNER="sudopark"
PROJECT_NUMBER=2
PROJECT_ID="PVT_kwHOA16qY84AMwiZ"
STATUS_FIELD_ID="PVTSSF_lAHOA16qY84AMwiZzgII9oA"

usage() {
    echo "usage: $0 <issue-number> <status>" >&2
    echo "  status: backlog | Todo | In Progress | Review + QA | Done | Completed | Archive" >&2
    exit 2
}

[ $# -eq 2 ] || usage
ISSUE="$1"
STATUS="$2"

case "$STATUS" in
    "backlog")      OPTION_ID="110a8c3c" ;;
    "Todo")         OPTION_ID="f75ad846" ;;
    "In Progress")  OPTION_ID="47fc9ee4" ;;
    "Review + QA")  OPTION_ID="fc0149fe" ;;
    "Done")         OPTION_ID="98236657" ;;
    "Completed")    OPTION_ID="880820ee" ;;
    "Archive")      OPTION_ID="732ad6d3" ;;
    *) echo "unknown status: $STATUS" >&2; usage ;;
esac

REPO_URL=$(gh repo view --json url --jq .url)
ITEM_ID=$(gh project item-add "$PROJECT_NUMBER" --owner "$OWNER" \
    --url "$REPO_URL/issues/$ISSUE" --format json --jq .id)

gh project item-edit --id "$ITEM_ID" --project-id "$PROJECT_ID" \
    --field-id "$STATUS_FIELD_ID" --single-select-option-id "$OPTION_ID" >/dev/null

echo "#$ISSUE → $STATUS"
