#!/bin/bash
# impact-check.sh — 변경 파일 기반 영향도 판정: 테스트 스킴 / tuist generate / 짝지어진 두 위치
#
# 테스트 스킴은 CI detect-changes 와 같은 scripts/derive-test-schemes.py --changed 가 계산한다.
#
# Usage:
#   impact-check.sh [--base <ref>]   # git 변경분(작업트리+커밋 vs ref, 기본 origin/develop) 분석
#   impact-check.sh --stdin          # "STATUS<TAB>PATH" 라인들을 stdin으로 (테스트용)
set -o pipefail

# git 모드 테스트는 임시 repo 에서 돈다 — 도출 스크립트는 작업 디렉터리가 아니라 이 스크립트의 레포에서 찾는다
DERIVE_TEST_SCHEMES="$(dirname "${BASH_SOURCE[0]}")/../../../../scripts/derive-test-schemes.py"

MODE="git"; BASE="origin/develop"
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

# ---- 테스트 스킴 ----
SCHEMES=$(printf '%s\n' "$FILES" | python3 "$DERIVE_TEST_SCHEMES" --changed) || exit 1

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
if [ -z "$SCHEMES" ]; then
  echo "(테스트 무관 변경)"
else
  printf '%s\n' "$SCHEMES" | tr '\n' ' ' | sed 's/ $//'
  echo ""
fi

# ---- 짝지어진 두 위치 ----
echo "## 짝지어진 두 위치"
warns=()
if [ "$MODE" = "git" ] && printf '%s\n' "$FILES" | grep -q "^TodoCalendarApp/Sources/AppEnvironment\.swift$"; then
  # 떠나는 버전 N 을 뽑아 case N 추가 여부로 판정한다. migrateStatement 문자열 grep 은
  # 컨텍스트를 좁히면 case 만 추가한 변경을 놓치고, 넓히면 무관한 테이블 편집이 누락을 가린다.
  oldMainDBVersion=$(git diff "$BASE" -- TodoCalendarApp/Sources/AppEnvironment.swift 2>/dev/null \
    | sed -n 's/^-[[:space:]]*static let dbVersion: Int32 = \([0-9][0-9]*\).*/\1/p' | head -1)
  if [ -n "$oldMainDBVersion" ]; then
    if ! git diff "$BASE" -- Repository 2>/dev/null | grep -qE "^\+[[:space:]]*case ${oldMainDBVersion}:"; then
      warns+=("- ⚠️ dbVersion 변경 감지 — Table.migrateStatement(for:) 에 case ${oldMainDBVersion} 추가가 함께 안 됨. 짝 확인 필요")
    fi
    if ! printf '%s\n' "$FILES" | grep -q 'AppDataMigrationImple\.swift$'; then
      warns+=("- ⚠️ dbVersion 변경 감지 — AppDataMigrationImple 의 runDBMigration case + runMigrationVersionNtoM 이 함께 안 됨. 없으면 migrateStatement 가 호출조차 안 된다")
    fi
  fi
  # 외부 캘린더 DB 는 서비스마다 같은 짝을 따로 가진다. 스텝 메서드 이름이 runMigrationVersionNtoM
  # 패턴이 아니라 대상 테이블을 담으므로, 위 메인 DB 검사의 앵커로는 안 걸린다.
  for externalDBPair in "googleCalendarDBVersion:runGoogleCalendarDBMigration" \
                        "appleCalendarDBVersion:runAppleCalendarDBMigration"; do
    externalDBConst=${externalDBPair%%:*}
    externalDBFunc=${externalDBPair##*:}
    oldExternalDBVersion=$(git diff "$BASE" -- TodoCalendarApp/Sources/AppEnvironment.swift 2>/dev/null \
      | sed -n "s/^-[[:space:]]*static let ${externalDBConst}: Int32 = \([0-9][0-9]*\).*/\1/p" | head -1)
    [ -n "$oldExternalDBVersion" ] || continue
    if ! git diff "$BASE" -- Repository 2>/dev/null | grep -qE "^\+[[:space:]]*case ${oldExternalDBVersion}:"; then
      warns+=("- ⚠️ ${externalDBConst} 변경 감지 — Table.migrateStatement(for:) 에 case ${oldExternalDBVersion} 추가가 함께 안 됨. 짝 확인 필요")
    fi
    if ! printf '%s\n' "$FILES" | grep -q 'ExternalCalendarDBMigrationImple\.swift$'; then
      warns+=("- ⚠️ ${externalDBConst} 변경 감지 — ExternalCalendarDBMigrationImple 의 ${externalDBFunc} switch case + 스텝 메서드가 함께 안 됨. 없으면 migrateStatement 가 호출조차 안 된다")
    fi
  done
fi
if [ ${#warns[@]} -eq 0 ]; then
  echo "(해당 없음)"
else
  printf '%s\n' "${warns[@]}"
fi

# ---- 테스트 고정 sleep (testability §9) ----
# §9 는 "안 일어남" 단언·정착 대기에만 sleep 을 허용한다. 줄만 보고는 그 판별이 안 돼 경고만 낸다.
echo "## 테스트 대기"
sleepHits=()
if [ "$MODE" = "git" ]; then
  # rename 은 old 경로를 pathspec 에 같이 넣어야 git 이 쌍으로 보고 추가 줄을 0 으로 센다
  while IFS=$'\t' read -r status firstPath secondPath; do
    testFile=${secondPath:-$firstPath}
    case "$status" in D*) continue ;; esac
    printf '%s' "$testFile" | grep -qE '/Tests/.*\.swift$' || continue
    if git ls-files --error-unmatch "$testFile" >/dev/null 2>&1; then
      addedSleeps=$(git diff -M "$BASE" -- "$firstPath" "$testFile" 2>/dev/null | grep -E '^\+' | grep -cE 'Task\.sleep|usleep\(|asyncAfter')
    else
      addedSleeps=$(grep -cE 'Task\.sleep|usleep\(|asyncAfter' "$testFile" 2>/dev/null)
    fi
    [ "${addedSleeps:-0}" -gt 0 ] && sleepHits+=("- ⚠️ ${testFile} — 고정 대기 ${addedSleeps}건 추가. 각각이 \"안 일어남\" 단언이나 50ms 정착 대기인지 확인하고, 효과 도착을 기다리는 자리면 waitEffect 로 바꾼다")
  done < <(printf '%s\n' "$CHANGES" | sort -u)
fi
if [ ${#sleepHits[@]} -eq 0 ]; then
  echo "(해당 없음)"
else
  printf '%s\n' "${sleepHits[@]}"
fi
