#!/bin/bash
# capture-event-screenshots.sh 의 촬영 전 가드 회귀 (xcodebuild 를 타지 않는 구간).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0

EVENT="_capture_test"
EVENT_DIR="fastlane/in_app_events/$EVENT"
trap 'rm -rf "$ROOT/$EVENT_DIR"' EXIT

assert_contains() { # desc pattern actual
  if printf '%s' "$3" | grep -qF -- "$2"; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  pattern [$2] not in:"; printf '%s\n' "$3" | sed 's/^/    /'
  fi
}

write_config() { # <captureSuites JSON 배열>
  mkdir -p "$EVENT_DIR"
  cat > "$EVENT_DIR/event.json" <<JSON
{
  "ascEventId": "0",
  "badge": "SPECIAL_EVENT",
  "scenes": {
    "card": "CalendarScenes/CalendarScenesCatalogSnapshots/test_storeCalendar.storeCalendar-light.png",
    "detail": "EventDetailScene/EventDetailSceneCatalogSnapshots/test_eventDetail.eventDetail-light.png"
  },
  "captureSuites": $1,
  "style": { "backgroundTop": "#000000", "backgroundBottom": "#111111", "cardTiltDegrees": 7 }
}
JSON
}

assert_contains "인자 부족이면 usage" "usage:" "$(scripts/capture-event-screenshots.sh 2>&1)"
assert_contains "event.json 이 없으면 끊는다" "이벤트 설정을 먼저 만들어라" \
  "$(scripts/capture-event-screenshots.sh nope ko 2>&1)"

write_config '["CalendarScenesSnapshots|CalendarScenesCatalogSnapshots"]'
# captureSuites 가 detail 장면의 스위트를 안 덮으면, snapshot-catalog 에 남은 이전 실행 산출물이
# 조용히 복사돼 언어도 기기 규격도 다른 이미지가 섞인다
MISSED="$(scripts/capture-event-screenshots.sh "$EVENT" ko 2>&1)"
assert_contains "안 덮이는 장면을 촬영 전에 끊는다" "captureSuites 가 안 덮는 장면이 있다" "$MISSED"
assert_contains "어느 장면인지 짚는다" "EventDetailSceneCatalogSnapshots" "$MISSED"
if printf '%s' "$MISSED" | grep -qF "촬영 시작"; then
  FAIL=$((FAIL+1)); echo "FAIL: 가드가 촬영보다 앞서야 한다"
else
  PASS=$((PASS+1))
fi

write_config '[]'
assert_contains "captureSuites 가 비면 두 장면 다 짚는다" "CalendarScenesCatalogSnapshots" \
  "$(scripts/capture-event-screenshots.sh "$EVENT" ko 2>&1)"

python3 - "$EVENT_DIR/event.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
config = json.loads(path.read_text())
del config["scenes"]["detail"]
path.write_text(json.dumps(config))
PY
assert_contains "scenes 키 결손을 짚는다" "scenes.detail 가 없다" \
  "$(scripts/capture-event-screenshots.sh "$EVENT" ko 2>&1)"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
