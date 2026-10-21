#!/bin/bash
# build_event_sources.py 장면 조립 회귀 — home-screen 조립의 규격·위젯 선택·누락 처리를 본다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0

EVENT="_build_sources_test"
LANG_DIR="_build_sources_test"
EVENT_DIR="fastlane/in_app_events/$EVENT"
WIDGET_DIR="snapshot-appstore/$LANG_DIR/widgets"
OUT="snapshot-event/$EVENT/$LANG_DIR"
trap 'rm -rf "$ROOT/$EVENT_DIR" "$ROOT/snapshot-event/$EVENT" "$ROOT/snapshot-appstore/$LANG_DIR"' EXIT

check() { # desc status [실제값]
  if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 ${3:+(실제 $3)}"; fi
}

write_event() { # card_json
  cat > "$EVENT_DIR/event.json" <<JSON
{ "ascEventId": "0", "scenes": { "card": $1, "detail": { "assemble": "home-screen" } } }
JSON
}

rm -rf "$EVENT_DIR" "snapshot-event/$EVENT" "snapshot-appstore/$LANG_DIR"
mkdir -p "$EVENT_DIR" "$WIDGET_DIR"

# 위젯 촬영본 대역 — 이름마다 다른 색이라 어느 위젯이 얹혔는지 픽셀로 가른다.
# 실제 촬영본처럼 흰 여백 안에 위젯이 있어야 store_screen 의 여백 자르기를 통과한다
python3 - "$WIDGET_DIR" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageDraw

directory = Path(sys.argv[1])
colors = {"dday-photo": "#E23D3D", "today-and-next-styled": "#3DE23D", "month": "#3D3DE2", "foremost": "#E2E23D"}
for name, color in colors.items():
    width = 594 if name == "foremost" else 1176
    capture = Image.new("RGBA", (width, 594), "#FFFFFF")
    ImageDraw.Draw(capture).rectangle([30, 30, width - 31, 563], fill=color)
    capture.save(directory / f"{name}.png")
PY

colors_at_center() { # file → 위젯 자리(가로 가운데)를 세로로 훑어 만난 대역 색 이름
  python3 - "$1" <<'PY'
import sys
from PIL import Image

names = {(226, 61, 61): "dday-photo", (61, 226, 61): "today-and-next-styled",
         (61, 61, 226): "month", (226, 226, 61): "foremost"}
with Image.open(sys.argv[1]) as image:
    rgb = image.convert("RGB")
    print(rgb.size[0], rgb.size[1])
    seen = []
    for y in range(0, rgb.size[1], 10):
        name = names.get(rgb.getpixel((rgb.size[0] // 2, y)))
        if name and name not in seen:
            seen.append(name)
    print(" ".join(seen))
PY
}

# 기본 위젯 목록으로 1320×2868 홈 화면을 조립한다
write_event '{ "assemble": "home-screen" }'
python3 scripts/build_event_sources.py "$EVENT" "$LANG_DIR" > /tmp/build-sources-default.log 2>&1
check "기본 home-screen 조립이 성공한다" $?
result="$(colors_at_center "$OUT/s1-card-source.png")"
size="$(echo "$result" | sed -n 1p)"; order="$(echo "$result" | sed -n 2p)"
[ "$size" = "1320 2868" ]
check "home-screen 이 1320×2868 이다" $? "$size"
[ "$order" = "dday-photo today-and-next-styled month" ]
check "기본 목록 셋이 위에서부터 얹힌다" $? "$order"

# widgets 를 주면 그 위젯만 얹는다
write_event '{ "assemble": "home-screen", "widgets": ["foremost", "month"] }'
python3 scripts/build_event_sources.py "$EVENT" "$LANG_DIR" > /tmp/build-sources-widgets.log 2>&1
check "widgets 지정 조립이 성공한다" $?
order="$(colors_at_center "$OUT/s1-card-source.png" | sed -n 2p)"
[ "$order" = "foremost month" ]
check "widgets 로 고른 위젯만 그 순서로 얹힌다" $? "$order"

# 위젯 촬영본이 없으면 누락 경로를 짚고 실패한다
write_event '{ "assemble": "home-screen", "widgets": ["event-list"] }'
python3 scripts/build_event_sources.py "$EVENT" "$LANG_DIR" > /tmp/build-sources-missing.log 2>&1
[ $? -ne 0 ] && grep -q "누락: snapshot-appstore/$LANG_DIR/widgets/event-list.png" /tmp/build-sources-missing.log
check "없는 위젯 촬영본을 짚고 실패한다" $?

# 모르는 종류를 받으면 아는 종류에 home-screen 을 함께 알린다
write_event '{ "assemble": "home-scren" }'
python3 scripts/build_event_sources.py "$EVENT" "$LANG_DIR" > /tmp/build-sources-unknown.log 2>&1
[ $? -ne 0 ] && grep -q "home-screen" /tmp/build-sources-unknown.log
check "모르는 assemble 종류 메시지가 home-screen 을 안내한다" $?

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
