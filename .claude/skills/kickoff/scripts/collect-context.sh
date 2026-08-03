#!/bin/bash
# kickoff 컨텍스트 수집: 이슈 본문·코멘트 + 관련 커밋·PR + 본문에 언급된 이슈
# usage: collect-context.sh <issue-number|issue-url>
set -o pipefail

N=$(echo "$1" | grep -oE '[0-9]+' | head -1)
if [ -z "$N" ]; then
  echo "(이슈 번호 인수 없음 — 유저에게 이슈 번호를 확인할 것)"
  exit 0
fi

echo "## Issue #$N"
if ! gh issue view "$N" --json title,state,body --jq '"[\(.state)] \(.title)\n\n\(.body)"'; then
  echo "(이슈 #$N 조회 실패 — 번호 확인 필요)"
  exit 0
fi

echo ""
echo "## 코멘트"
gh issue view "$N" --json comments --jq 'if (.comments | length) == 0 then "(없음)" else .comments[] | "--- \(.author.login) (\(.createdAt)):\n\(.body)\n" end'

echo ""
echo "## 관련 커밋 (git log --all --grep \"[#$N]\")"
COMMITS=$(git log --all --grep="\[#$N\]" --oneline --no-merges | head -40)
if [ -z "$COMMITS" ]; then echo "(없음)"; else echo "$COMMITS"; fi

echo ""
echo "## 관련 PR (제목에 [#$N])"
PRS=$(gh pr list --state all --limit 200 --json number,title,state --jq ".[] | select(.title | contains(\"[#$N]\")) | \"PR#\(.number) [\(.state)] \(.title)\"")
if [ -z "$PRS" ]; then echo "(없음)"; else echo "$PRS"; fi

echo ""
echo "## 본문에 언급된 다른 이슈"
MENTIONED=$(gh issue view "$N" --json body --jq .body | grep -oE '#[0-9]+' | tr -d '#' | sort -u | grep -v "^$N\$")
if [ -z "$MENTIONED" ]; then
  echo "(없음)"
else
  for m in $MENTIONED; do
    gh issue view "$m" --json number,title,state --jq '"#\(.number) [\(.state)] \(.title)"' 2>/dev/null
  done
fi
