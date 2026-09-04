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

# 시뮬레이터는 CI·로컬이 같은 것을 쓴다 — 해석은 ensure-test-simulator.sh 가 단독으로 한다
if [ -z "${DESTINATION:-}" ]; then
  SIMULATOR_UDID="$("$(dirname "${BASH_SOURCE[0]}")/ensure-test-simulator.sh")"
  DESTINATION="platform=iOS Simulator,id=${SIMULATOR_UDID}"
fi

ALL_SCHEMES=(
  "Extensions"
  "Domain"
  "Repository"
  "AuthService"
  "BillingScenes"
  "CalendarScenes"
  "EventDetailScene"
  "EventListScenes"
  "SettingScene"
  "MemberScenes"
  "AIAgentScene"
  "TodoCalendarApp"
  "TodoCalendarAppWidget"
  "TodoCalendarAppShare"
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

  TMPFILE=$(mktemp)
  xcodebuild test \
    -workspace "${WORKSPACE}" \
    -scheme "${scheme}" \
    -destination "${DESTINATION}" \
    -testLanguage en \
    -testRegion en_US \
    2>&1 | tee "$TMPFILE" | xcpretty
  # PIPESTATUS[0]은 파이프 직후에만 유효 — xcpretty가 아닌 xcodebuild의 종료 코드
  EXIT_CODE=${PIPESTATUS[0]}
  OUTPUT=$(cat "$TMPFILE")
  rm -f "$TMPFILE"

  # 실행된 테스트가 하나도 없으면 통과로 보지 않는다 (XCTest·Swift Testing 양쪽 마커 부재)
  RAN_XCTEST=$(echo "$OUTPUT" | grep -c "Executed [1-9][0-9]* test" || true)
  RAN_SWIFT_TESTING=$(echo "$OUTPUT" | grep -c "Test run with [1-9][0-9]* test" || true)

  if [ "$EXIT_CODE" -ne 0 ]; then
    FAILED+=("${scheme}")
    echo "  -> FAILED (exit ${EXIT_CODE})"
    echo "$OUTPUT" | grep -E "(error:|BUILD FAILED|\*\* TEST FAILED \*\*|suites failed)" | head -5
  elif [ "$RAN_XCTEST" -eq 0 ] && [ "$RAN_SWIFT_TESTING" -eq 0 ]; then
    FAILED+=("${scheme}")
    echo "  -> FAILED (실행된 테스트 없음)"
  else
    PASSED+=("${scheme}")
    echo "  -> PASSED"
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
