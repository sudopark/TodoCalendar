#!/bin/bash
# compose-creative-assets.py 합성 규칙 회귀.
# 업로드 규격(헤더 3840×1646·검색 결과 3840×2560·알파 없음)과 배치 방향이 코드로 지켜지는지 본다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0

LANG_ID="_creative_test"
SOURCE_DIR="snapshot-appstore/$LANG_ID"
# CONFIG_ROOT 는 ROOT 안이어야 한다 — 스크립트가 에러 문구에 상대 경로를 쓴다
CONFIG_DIR="snapshot-appstore/_creative_test_config"
export CREATIVE_CONFIG_ROOT="$ROOT/$CONFIG_DIR"
trap 'rm -rf "$ROOT/$SOURCE_DIR" "$ROOT/$CONFIG_DIR"' EXIT

assert() { # desc actual_exit
  if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; fi
}

write_assets() { # header_scenes_json search_scenes_json
  cat > "$CONFIG_DIR/assets.json" <<JSON
{
  "header": { "captionKey": "header", "scenes": $1 },
  "search": { "captionKey": "search", "scenes": $2 }
}
JSON
}

rm -rf "$SOURCE_DIR" "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"
write_assets '["C2", "C3", "C4"]' '["C2", "C3", "C4"]'

# 촬영 산출물 대역 — 규격만 같으면 기하 검증엔 충분하다.
# 단색 한 장으로는 안 된다: 위젯 여백 제거가 배경 아닌 픽셀을 찾는다
python3 - "$SOURCE_DIR" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
(root / "widgets").mkdir(parents=True, exist_ok=True)
(root / "captions" / "creative").mkdir(parents=True, exist_ok=True)


def block(size, background, box, fill):
    image = Image.new("RGB", size, background)
    ImageDraw.Draw(image).rectangle(box, fill=fill)
    return image


for slug in ["01-calendar", "07-todo-list"]:
    block((1320, 2868), (245, 245, 247), (80, 200, 1240, 2400), (30, 90, 200)).save(root / f"{slug}.png")

for name in ["dday-photo", "today-and-next-styled", "month"]:
    block((480, 480), (0, 0, 0), (40, 40, 440, 440), (210, 210, 220)).save(root / "widgets" / f"{name}.png")

# 캡션 대역은 test_creativeAssetCaptions 캔버스(@3x)와 같은 크기로, 글자 자리를 빨간 띠로 칠한다
block((1260, 1620), (245, 245, 247), (100, 700, 1160, 920), (220, 0, 0)).save(root / "captions" / "creative" / "header.png")
block((3840, 510), (245, 245, 247), (600, 180, 3240, 330), (220, 0, 0)).save(root / "captions" / "creative" / "search.png")
print("stand-in ok")
PY

python3 scripts/compose-creative-assets.py --locale "$LANG_ID" > /tmp/creative-compose-test.log 2>&1
assert "합성이 성공한다" $?

python3 - "$CONFIG_DIR" <<'PY'
import sys
from pathlib import Path
from PIL import Image

out = Path(sys.argv[1]) / "images" / "_creative_test"
failures = []
expected = {"header.png": (3840, 1646), "search.png": (3840, 2560)}
actual = sorted(path.name for path in out.glob("*.png"))
if actual != sorted(expected):
    failures.append(f"산출물 {actual}")

for name, size in expected.items():
    with Image.open(out / name) as image:
        if image.size != size:
            failures.append(f"{name}: {image.size}")
        if image.mode != "RGB" or "transparency" in image.info:
            failures.append(f"{name}: mode={image.mode}")
        if image.format != "PNG":
            failures.append(f"{name}: format={image.format}")

red = (220, 0, 0)
# 헤더 캡션은 왼쪽 칸에 들고 기기 줄은 오른쪽에 붙는다
with Image.open(out / "header.png") as header:
    if header.getpixel((700, 823)) != red:
        failures.append("헤더 캡션이 왼쪽 칸 가운데에 없다")
    if header.getpixel((3840 - 140 - 350, 823)) == header.getpixel((700, 100)):
        failures.append("헤더 오른쪽 끝에 기기가 없다")
# 검색 결과 캡션은 위에 들고 기기 줄은 아래에 놓인다
with Image.open(out / "search.png") as search:
    if search.getpixel((1920, 315)) != red:
        failures.append("검색 결과 캡션이 위쪽 가운데에 없다")
    if search.getpixel((1920, 1600)) == search.getpixel((1920, 20)):
        failures.append("검색 결과 아래쪽에 기기가 없다")

if failures:
    print("\n".join(failures))
    sys.exit(1)
PY
assert "해상도·알파·PNG·배치 방향이 규격대로다" $?

mkdir -p "$CONFIG_DIR/images/_creative_test"
printf 'x' > "$CONFIG_DIR/images/_creative_test/stale.png"
python3 scripts/compose-creative-assets.py --locale "$LANG_ID" > /dev/null 2>&1
test ! -f "$CONFIG_DIR/images/_creative_test/stale.png"
assert "지난 회차 산출물을 지우고 쓴다" $?

python3 scripts/compose-creative-assets.py 2>&1 | grep -qF -- "--locale <lang> 또는 --all-locales"
assert "로케일 인자가 없으면 끊는다" $?

write_assets '["C2", "C3", "CX"]' '["C2", "C3", "C4"]'
python3 scripts/compose-creative-assets.py --locale "$LANG_ID" 2>&1 | grep -qF "모르는 장면: CX"
assert "모르는 장면은 끊는다" $?

write_assets '["C2", "C3", "C4", "C3"]' '["C2", "C3", "C4"]'
python3 scripts/compose-creative-assets.py --locale "$LANG_ID" 2>&1 | grep -qF "장면이 4개다"
assert "장면이 3개를 넘으면 끊는다" $?

cat > "$CONFIG_DIR/assets.json" <<'JSON'
{
  "header": { "captionKey": "hero", "scenes": ["C2", "C3", "C4"] },
  "search": { "captionKey": "search", "scenes": ["C2", "C3", "C4"] }
}
JSON
python3 scripts/compose-creative-assets.py --locale "$LANG_ID" 2>&1 | grep -qF "배치 이름과 같아야 한다"
assert "captionKey 가 배치 이름과 다르면 끊는다" $?

write_assets '["C2", "C3", "C4"]' '["C2", "C3", "C4"]'
python3 scripts/compose-creative-assets.py --locale "$LANG_ID" > /dev/null 2>&1
rm -f "$SOURCE_DIR/07-todo-list.png"
python3 scripts/compose-creative-assets.py --locale "$LANG_ID" 2>&1 | grep -qF "07-todo-list.png"
assert "촬영물이 없으면 그 파일을 가리키며 끊는다" $?
test -f "$CONFIG_DIR/images/_creative_test/header.png" && test -f "$CONFIG_DIR/images/_creative_test/search.png"
assert "합성이 끊겨도 지난 회차 산출물은 남는다" $?

cp "$SOURCE_DIR/01-calendar.png" "$SOURCE_DIR/07-todo-list.png"
rm -f "$SOURCE_DIR/captions/creative/search.png"
python3 scripts/compose-creative-assets.py --locale "$LANG_ID" 2>&1 | grep -qF "fastlane/creative_assets/captions.json"
assert "캡션이 없으면 captions.json 을 가리키며 끊는다" $?

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
