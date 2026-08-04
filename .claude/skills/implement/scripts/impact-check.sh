#!/bin/bash
# impact-check.sh — 변경 파일 기반 영향도 판정: 테스트 스킴 / tuist generate / 짝지어진 두 위치
#
# ⚠️ 짝지어진 두 위치: 아래 스킴 매핑은 .github/workflows/pr_test.yml 의
#    "Map changes to test schemes" 스텝을 미러링한다. 한쪽 수정 시 반드시 동기화.
#
# Usage:
#   impact-check.sh [--base <ref>]   # git 변경분(작업트리+커밋 vs ref, 기본 develop) 분석
#   impact-check.sh --stdin          # "STATUS<TAB>PATH" 라인들을 stdin으로 (테스트용)
set -o pipefail

ALL_SCHEMES="Domain Repository AuthService BillingScenes CalendarScenes EventDetailScene EventListScenes SettingScene MemberScenes AIAgentScene TodoCalendarApp TodoCalendarAppWidget"
ALL_PRESENTATION="BillingScenes CalendarScenes EventDetailScene EventListScenes SettingScene MemberScenes AIAgentScene"

MODE="git"; BASE="develop"
while [ $# -gt 0 ]; do
  case "$1" in
    --stdin) MODE="stdin"; shift ;;
    --base) [ $# -ge 2 ] || { echo "--base requires a ref" >&2; exit 1; }; BASE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ "$MODE" = "stdin" ]; then
  CHANGES=$(cat)
else
  git rev-parse --verify --quiet "$BASE" >/dev/null || { echo "invalid base ref: $BASE" >&2; exit 1; }
  # CI(pr_test.yml)의 3-dot diff(merge-base 기준)와 동일한 비교 대상이 되도록 BASE를 merge-base로 치환
  BASE=$(git merge-base "$BASE" HEAD) || { echo "no merge-base between $BASE and HEAD" >&2; exit 1; }
  CHANGES=$(
    git diff --name-status "$BASE"
    git ls-files --others --exclude-standard | sed $'s/^/A\t/'
  )
fi

# R100<TAB>old<TAB>new 같은 rename은 old/new 경로 모두 영향 대상
FILES=$(printf '%s\n' "$CHANGES" | awk -F'\t' 'NF>=2 {for (i=2; i<=NF; i++) print $i}')

# ---- 테스트 스킴 (pr_test.yml detect-changes 미러) ----
schemes=()
if printf '%s\n' "$FILES" | grep -qE "^(Package\.swift|Package\.resolved|Tuist/|Tuist\.swift|mise\.toml)"; then
  schemes+=($ALL_SCHEMES)
fi
if printf '%s\n' "$FILES" | grep -qE "^Supports/(Common3rdParty|Extensions/Sources|UnitTestHelpKit/Sources)/"; then
  schemes+=($ALL_SCHEMES)
fi
if printf '%s\n' "$FILES" | grep -q "^Supports/Extensions/"; then
  schemes+=("Extensions")
fi
if printf '%s\n' "$FILES" | grep -q "^Supports/TestDoubles/Sources/"; then
  schemes+=("Repository" $ALL_PRESENTATION "TodoCalendarApp" "TodoCalendarAppWidget")
fi
if printf '%s\n' "$FILES" | grep -q "^Domain/Sources/"; then
  schemes+=($ALL_SCHEMES)
fi
if printf '%s\n' "$FILES" | grep -q "^Domain/Tests/"; then
  schemes+=("Domain")
fi
if printf '%s\n' "$FILES" | grep -q "^Repository/Sources/"; then
  schemes+=("Repository" "TodoCalendarApp" "TodoCalendarAppWidget")
fi
if printf '%s\n' "$FILES" | grep -q "^Repository/Tests/"; then
  schemes+=("Repository")
fi
if printf '%s\n' "$FILES" | grep -q "^Services/AuthService/Sources/"; then
  schemes+=("AuthService" "TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^Services/AuthService/Tests/"; then
  schemes+=("AuthService")
fi
if printf '%s\n' "$FILES" | grep -qE "^Services/(FirstPartyServices|SpeechService|PlaceService|ExternalServices|StoreKitService)/"; then
  schemes+=("TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/CommonPresentation/"; then
  schemes+=($ALL_PRESENTATION "TodoCalendarApp" "TodoCalendarAppWidget")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/Scenes/"; then
  schemes+=($ALL_PRESENTATION "TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/BillingScenes/"; then
  schemes+=("BillingScenes")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/CalendarScenes/"; then
  schemes+=("CalendarScenes" "TodoCalendarApp" "TodoCalendarAppWidget")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/EventDetailScene/"; then
  schemes+=("EventDetailScene" "TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/EventListScenes/"; then
  schemes+=("EventListScenes" "TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/SettingScene/"; then
  schemes+=("SettingScene" "TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/MemberScenes/"; then
  schemes+=("MemberScenes" "TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^Presentations/AIAgentScene/"; then
  schemes+=("AIAgentScene")
fi
if printf '%s\n' "$FILES" | grep -qE "^TodoCalendarApp/(Sources|Tests)/"; then
  schemes+=("TodoCalendarApp")
fi
if printf '%s\n' "$FILES" | grep -q "^TodoCalendarApp/AppExtensions/Widget/"; then
  schemes+=("TodoCalendarAppWidget")
fi

# ---- tuist generate (테스트보다 선행 액션 — 첫 섹션으로 출력) ----
# tuist 재생성 필요: (1) .swift 소스 멤버십 추가/삭제/이동(ADRC), (2) 매니페스트(Project/Workspace/Package/Tuist) 변경(수정 포함).
# 비소스(.md·png·.claude·scripts 등) 추가는 무관.
echo "## tuist generate"
ADRC_SWIFT=$(printf '%s\n' "$CHANGES" | awk -F'\t' 'substr($1,1,1) ~ /[ADRC]/ {for (i=2; i<=NF; i++) print $i}' | grep '\.swift$')
MANIFEST=$(printf '%s\n' "$FILES" | grep -E '(^|/)(Project|Workspace)\.swift$|^(Package\.(swift|resolved)|Tuist\.swift)$|^Tuist/')
if [ -n "$ADRC_SWIFT" ] || [ -n "$MANIFEST" ]; then
  echo "필요 — .swift 추가/삭제/이동 또는 매니페스트 변경 감지"
else
  echo "불필요"
fi

echo "## 테스트 스킴"
if [ ${#schemes[@]} -eq 0 ]; then
  echo "(테스트 무관 변경)"
else
  printf '%s\n' "${schemes[@]}" | sort -u | tr '\n' ' ' | sed 's/ $//'
  echo ""
fi

# ---- 짝지어진 두 위치 ----
echo "## 짝지어진 두 위치"
warns=()
if printf '%s\n' "$FILES" | grep -q "^\.github/workflows/pr_test\.yml$"; then
  warns+=("- ⚠️ pr_test.yml 변경 — detect-changes 매핑 ↔ Test step ↔ impact-check.sh 매핑 3곳 동기화 확인")
fi
if [ "$MODE" = "git" ] && printf '%s\n' "$FILES" | grep -q "^TodoCalendarApp/Sources/AppEnvironment\.swift$"; then
  if git diff "$BASE" -- TodoCalendarApp/Sources/AppEnvironment.swift 2>/dev/null | grep -qi '^[+-].*dbVersion'; then
    if ! git diff "$BASE" -- Repository 2>/dev/null | grep -q 'migrateStatement'; then
      warns+=("- ⚠️ dbVersion 변경 감지 — Table.migrateStatement(for:) case 추가가 함께 안 됨. 짝 확인 필요")
    fi
  fi
fi
if [ ${#warns[@]} -eq 0 ]; then
  echo "(해당 없음)"
else
  printf '%s\n' "${warns[@]}"
fi
