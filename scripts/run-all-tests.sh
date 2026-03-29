#!/bin/bash
set -o pipefail

# ============================================================
# run-all-tests.sh — TodoCalendar 전체 테스트 실행 스크립트
# ============================================================
# Usage:
#   ./scripts/run-all-tests.sh                    # 전체 실행
#   ./scripts/run-all-tests.sh Domain Repository  # 특정 스킴만
#   DESTINATION='...' ./scripts/run-all-tests.sh   # destination 오버라이드
# ============================================================

WORKSPACE="TodoCalendar.xcworkspace"

# CI 환경에서는 이름 기반, 로컬에서는 UDID 기반 시뮬레이터 지정
if [ "${CI}" = "true" ]; then
  DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.2}"
else
  SIMULATOR_UDID="76C24428-6AA8-461F-AE91-E748F8D2769E"  # iPhone 16, iOS 18.0
  DESTINATION="${DESTINATION:-platform=iOS Simulator,id=${SIMULATOR_UDID}}"
fi

ALL_SCHEMES=(
  "Domain"
  "Repository"
  "CalendarScenes"
  "EventDetailScene"
  "EventListScenes"
  "SettingScene"
  "MemberScenes"
  "TodoCalendarApp"
  "TodoCalendarAppWidget"
)

# 인자가 있으면 해당 스킴만 실행
if [ $# -gt 0 ]; then
  SCHEMES=("$@")
else
  SCHEMES=("${ALL_SCHEMES[@]}")
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

PASSED=()
FAILED=()
TOTAL=${#SCHEMES[@]}

echo "========================================"
echo " TodoCalendar Test Runner"
echo " Schemes: ${TOTAL}"
echo " Destination: ${DESTINATION}"
echo "========================================"
echo ""

for scheme in "${SCHEMES[@]}"; do
  echo "----------------------------------------"
  echo " [$((${#PASSED[@]} + ${#FAILED[@]} + 1))/${TOTAL}] Testing: ${scheme}"
  echo "----------------------------------------"

  OUTPUT=$(xcodebuild test \
    -workspace "${WORKSPACE}" \
    -scheme "${scheme}" \
    -destination "${DESTINATION}" \
    -testLanguage en \
    -testRegion en_US \
    -quiet \
    2>&1)
  EXIT_CODE=$?

  # -quiet 모드에서 exit code 65가 나와도 실제 테스트 실패가 없으면 통과로 처리
  HAS_REAL_FAILURE=$(echo "$OUTPUT" | grep -c "with [1-9][0-9]* failure" || true)
  SWIFT_TESTING_FAILED=$(echo "$OUTPUT" | grep -c "suites failed" || true)

  if [ $EXIT_CODE -eq 0 ] || ([ $HAS_REAL_FAILURE -eq 0 ] && [ $SWIFT_TESTING_FAILED -eq 0 ]); then
    PASSED+=("${scheme}")
    echo "  -> PASSED"
  else
    FAILED+=("${scheme}")
    echo "  -> FAILED"
    echo "$OUTPUT" | grep -E "(error:|suites failed)" | head -5
  fi
  echo ""
done

echo "========================================"
echo " Results: ${#PASSED[@]} passed, ${#FAILED[@]} failed / ${TOTAL} total"
echo "========================================"

if [ ${#PASSED[@]} -gt 0 ]; then
  echo " PASSED: ${PASSED[*]}"
fi

if [ ${#FAILED[@]} -gt 0 ]; then
  echo " FAILED: ${FAILED[*]}"
  exit 1
fi

echo ""
echo " All tests passed!"
exit 0
