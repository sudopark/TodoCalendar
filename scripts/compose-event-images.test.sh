#!/bin/bash
# compose-event-images.py 합성 규칙 회귀.
# 지침의 하드 제약(하단 1/3 비움·정확한 해상도·알파 없음)이 코드로 지켜지는지 본다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0

EVENT="_compose_test"
EVENT_DIR="fastlane/in_app_events/$EVENT"
SOURCE_DIR="snapshot-event/$EVENT/ko"
trap 'rm -rf "$ROOT/$EVENT_DIR" "$ROOT/snapshot-event/$EVENT"' EXIT

assert() { # desc actual_exit
  if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; fi
}

rm -rf "$EVENT_DIR" "snapshot-event/$EVENT"
mkdir -p "$EVENT_DIR" "$SOURCE_DIR"
cat > "$EVENT_DIR/event.json" <<'JSON'
{
  "ascEventId": "0",
  "badge": "SPECIAL_EVENT",
  "scenes": { "card": "unused", "detail": "unused" },
  "captureSuites": [],
  "style": { "backgroundTop": "#2B3A67", "backgroundBottom": "#4A5D9B", "cardTiltDegrees": 7 }
}
JSON

# 소스 장면 대역 — 촬영 산출물과 같은 규격의 단색 이미지면 기하 검증엔 충분하다
python3 - "$SOURCE_DIR" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageDraw

directory = Path(sys.argv[1])
for name in ("s1-card-source.png", "s2-detail-source.png"):
    image = Image.new("RGB", (1320, 2868), "#FFFFFF")
    draw = ImageDraw.Draw(image)
    draw.rectangle([100, 100, 1220, 2768], fill="#E23D3D")
    image.save(directory / name)
PY

python3 scripts/compose-event-images.py --event "$EVENT" --locale ko > /tmp/compose-test.log 2>&1
assert "합성이 성공한다" $?

OUT="$EVENT_DIR/images/ko"
python3 - "$OUT" "$EVENT_DIR/event.json" <<'PY'
import json, sys
from pathlib import Path
from PIL import Image

out, config_path = Path(sys.argv[1]), Path(sys.argv[2])
style = json.loads(config_path.read_text())["style"]
failures = []

card_path = out / "event-card_1920x1080.png"
detail_path = out / "event-detail_1080x1920.png"

for path, expected in ((card_path, (1920, 1080)), (detail_path, (1080, 1920))):
    if not path.exists():
        failures.append(f"{path.name}: 산출물이 없다")
        continue
    with Image.open(path) as image:
        if image.size != expected:
            failures.append(f"{path.name}: {image.size} — {expected} 아님")
        if image.mode != "RGB":
            failures.append(f"{path.name}: mode={image.mode} — 알파가 남았다")

# 카드 하단 1/3 은 배경 그라데이션 그대로여야 한다 (App Store 가 이름·설명을 겹쳐 그린다)
if card_path.exists():
    import importlib.util
    spec = importlib.util.spec_from_file_location("compose_event_images", "scripts/compose-event-images.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    card_background = module.card_background
    with Image.open(card_path) as card:
        region = card.convert("RGB").crop((0, 720, 1920, 1080))
    expected_region = card_background(style).convert("RGB").crop((0, 720, 1920, 1080))
    if region.tobytes() != expected_region.tobytes():
        failures.append("event-card: 하단 1/3(y>=720)에 배경 아닌 픽셀이 있다")

if failures:
    print("\n".join(f"  ✗ {line}" for line in failures))
    sys.exit(1)
PY
assert "규격·알파·하단 1/3 이 지침대로다" $?

drawn_width() { # 배경 아닌 픽셀의 가로 폭 — 기기가 몇 대 섰는지의 대리 지표
    python3 - "$OUT/event-card_1920x1080.png" "$EVENT_DIR/event.json" <<'WIDTH'
import importlib.util, json, sys
from pathlib import Path
from PIL import Image, ImageChops

spec = importlib.util.spec_from_file_location("cei", "scripts/compose-event-images.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
style = json.loads(Path(sys.argv[2]).read_text())["style"]
with Image.open(sys.argv[1]) as card:
    box = ImageChops.difference(card.convert("RGB"), m.card_background(style)).getbbox()
print(box[2] - box[0] if box else 0)
WIDTH
}
SINGLE_WIDTH="$(drawn_width)"

# 카드 소스가 여러 장이면 기기를 여러 대 세운다. 기본 style 만으로 좌우 여백 안에 들어와야
# 새 이벤트가 코드 수정 없이 돈다 (지침 §4).
python3 - "$SOURCE_DIR" <<'TRIO'
import sys
from pathlib import Path
from PIL import Image, ImageDraw

directory = Path(sys.argv[1])
for index, color in ((2, "#2D8A4E"), (3, "#8A2D6F")):
    image = Image.new("RGB", (1320, 2868), "#FFFFFF")
    ImageDraw.Draw(image).rectangle([100, 100, 1220, 2768], fill=color)
    image.save(directory / f"s1-card-source-{index}.png")
TRIO
python3 scripts/compose-event-images.py --event "$EVENT" --locale ko > /tmp/compose-trio.log 2>&1
assert "기기 3대 카드가 기본 style 로 합성된다" $?
TRIO_WIDTH="$(drawn_width)"
if [ "$TRIO_WIDTH" -gt "$SINGLE_WIDTH" ]; then PASS=$((PASS+1)); else
  FAIL=$((FAIL+1)); echo "FAIL: 소스가 늘어도 기기가 한 대만 섰다 ($SINGLE_WIDTH → $TRIO_WIDTH)"; fi
rm -f "$SOURCE_DIR"/s1-card-source-2.png "$SOURCE_DIR"/s1-card-source-3.png

# 좌우 여백 가드 — 기기를 여러 대 세우면 열리는 실패 경로다. 하단과 같은 함수가 잡는지 본다.
python3 - <<'EDGE'
import importlib.util, sys
from PIL import Image

spec = importlib.util.spec_from_file_location("cei", "scripts/compose-event-images.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

background = m.card_background({"backgroundTop": "#000000", "backgroundBottom": "#111111"})
card = background.copy()
strip = Image.new("RGBA", (60, 200), (0, 255, 0, 255))
card.paste(strip, (10, 300), strip)
try:
    m.verify_card_clearances(card, background)
except SystemExit as error:
    sys.exit(0 if "좌우 여백" in str(error) else f"다른 사유로 끊김: {error}")
sys.exit("좌우 여백 가드가 침범을 통과시켰다")
EDGE
if [ $? -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: 좌우 여백 가드가 침범을 잡는다"; fi

# 하단 1/3 가드 — 배치가 하단을 보장하므로 CLI 로는 침범을 못 만든다.
# 가드가 살아 있는지는 함수를 직접 찔러 확인한다 (죽은 산식 가드로 되돌아가는 걸 막는 회귀).
python3 - <<'GUARD'
import importlib.util, sys
from PIL import Image

spec = importlib.util.spec_from_file_location("cei", "scripts/compose-event-images.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

background = m.card_background({"backgroundTop": "#000000", "backgroundBottom": "#111111"})
card = background.copy()
# 하단 1/3 을 실제로 침범하는 불투명 사각형
intruder = Image.new("RGBA", (200, 200), (255, 0, 0, 255))
card.paste(intruder, (900, 800), intruder)
try:
    m.verify_card_clearances(card, background)
except SystemExit as error:
    sys.exit(0 if "하단 1/3" in str(error) else f"다른 사유로 끊김: {error}")
sys.exit("가드가 침범을 통과시켰다")
GUARD
if [ $? -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: 하단 1/3 가드가 침범을 잡는다"; fi

# 기울임 허용 범위 밖은 끊긴다
python3 - "$EVENT_DIR/event.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
config = json.loads(path.read_text())
config["style"]["cardTiltDegrees"] = 25
path.write_text(json.dumps(config))
PY
python3 scripts/compose-event-images.py --event "$EVENT" --locale ko > /tmp/compose-tilt.log 2>&1
if [ $? -ne 0 ] && grep -q "5~10" /tmp/compose-tilt.log; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: 기울임 범위 밖이 끊긴다"; cat /tmp/compose-tilt.log; fi

# 소스 장면이 없으면 그 언어를 실패로 센다
rm -f "$SOURCE_DIR/s1-card-source.png"
python3 - "$EVENT_DIR/event.json" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
config = json.loads(path.read_text())
config["style"]["cardTiltDegrees"] = 7
path.write_text(json.dumps(config))
PY
python3 scripts/compose-event-images.py --event "$EVENT" --locale ko > /tmp/compose-missing.log 2>&1
if [ $? -ne 0 ] && grep -q "s1-card-source.png" /tmp/compose-missing.log; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: 소스 결손을 짚는다"; cat /tmp/compose-missing.log; fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
