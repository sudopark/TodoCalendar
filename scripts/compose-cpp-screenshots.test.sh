#!/bin/bash
# compose-cpp-screenshots.py 합성 규칙 회귀.
# 명세의 하드 제약(정확한 해상도·알파 없음·페이지당 6장·§3 배치 순서)이 코드로 지켜지는지 본다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0

LANG_ID="_cpp_test"
SOURCE_DIR="snapshot-appstore/$LANG_ID"
# CONFIG_ROOT 는 ROOT 안이어야 한다 — 스크립트가 에러 문구에 상대 경로를 쓴다
CONFIG_DIR="snapshot-appstore/_cpp_test_config"
export CPP_CONFIG_ROOT="$ROOT/$CONFIG_DIR"
trap 'rm -rf "$ROOT/$SOURCE_DIR" "$ROOT/$CONFIG_DIR"' EXIT

assert() { # desc actual_exit
  if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; fi
}

rm -rf "$SOURCE_DIR" "$CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/pages.json" <<'JSON'
{
  "page-a": { "ascPageId": "", "scenes": ["C1", "C2", "C3", "C4", "C5", "C6"] },
  "page-b": { "ascPageId": "", "scenes": ["C3", "C1", "C2", "C6", "C5", "C4"] }
}
JSON

# 촬영 산출물 대역 — 규격만 같으면 기하 검증엔 충분하다.
# 단색 한 장으로는 안 된다: 위젯 여백 제거와 시트 상단 탐지가 배경 아닌 픽셀을 찾는다
python3 - "$SOURCE_DIR" <<'PY'
import sys
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
(root / "widgets").mkdir(parents=True, exist_ok=True)
(root / "sheets").mkdir(parents=True, exist_ok=True)
(root / "captions" / "cpp").mkdir(parents=True, exist_ok=True)


def block(size, background, box, fill):
    image = Image.new("RGB", size, background)
    ImageDraw.Draw(image).rectangle(box, fill=fill)
    return image


for slug in ["01-calendar", "02-repeat-options", "07-todo-list", "08-share-preview"]:
    block((1320, 2868), (245, 245, 247), (80, 200, 1240, 2400), (30, 90, 200)).save(root / f"{slug}.png")

widgets = [
    "today-and-next", "month",
    "lockscreen-foremost", "lockscreen-next", "lockscreen-next-remain", "lockscreen-live-activity",
]
for name in widgets:
    block((480, 480), (0, 0, 0), (40, 40, 440, 440), (210, 210, 220)).save(root / "widgets" / f"{name}.png")

for name in ["ai-command-processing", "ai-command-done"]:
    block((1320, 900), (255, 255, 255), (120, 300, 1200, 800), (60, 60, 90)).save(root / "sheets" / f"{name}.png")

for index in range(1, 9):
    block((1320, 420), (245, 245, 247), (200, 150, 1120, 270), (29, 29, 31)).save(
        root / "captions" / "cpp" / f"C{index}.png"
    )
print("stand-in ok")
PY

python3 scripts/compose-cpp-screenshots.py --locale "$LANG_ID" > /tmp/cpp-compose-test.log 2>&1
assert "합성이 성공한다" $?

python3 - "$CONFIG_DIR" <<'PY'
import sys
from pathlib import Path
from PIL import Image

config = Path(sys.argv[1])
failures = []

expected = {
    "page-a": ["01_C1.png", "02_C2.png", "03_C3.png", "04_C4.png", "05_C5.png", "06_C6.png"],
    "page-b": ["01_C3.png", "02_C1.png", "03_C2.png", "04_C6.png", "05_C5.png", "06_C4.png"],
}
for page, names in expected.items():
    out = config / page / "images" / "_cpp_test"
    actual = sorted(path.name for path in out.glob("*.png"))
    if actual != names:
        failures.append(f"{page}: 라인업 {actual}")

for page in expected:
    for path in (config / page / "images" / "_cpp_test").glob("*.png"):
        with Image.open(path) as image:
            if image.size != (1320, 2868):
                failures.append(f"{path.name}: {image.size}")
            if image.mode != "RGB":
                failures.append(f"{path.name}: mode={image.mode}")

# 같은 장면은 페이지가 달라도 같은 이미지여야 한다 — 번호만 바뀐다
a_c3 = (config / "page-a" / "images" / "_cpp_test" / "03_C3.png").read_bytes()
b_c3 = (config / "page-b" / "images" / "_cpp_test" / "01_C3.png").read_bytes()
if a_c3 != b_c3:
    failures.append("C3 이 페이지마다 다르게 합성됐다")

if failures:
    print("\n".join(failures))
    sys.exit(1)
PY
assert "해상도·알파·라인업 순서·장면 재사용이 명세대로다" $?

python3 scripts/compose-cpp-screenshots.py --locale "$LANG_ID" --page page-a > /dev/null 2>&1
test -f "$CONFIG_DIR/page-a/images/_cpp_test/01_C1.png"
assert "--page 로 지정한 페이지를 만든다" $?

python3 scripts/compose-cpp-screenshots.py --locale "$LANG_ID" --page no-such-page > /dev/null 2>&1
test $? -ne 0
assert "모르는 페이지는 끊는다" $?

python3 scripts/compose-cpp-screenshots.py > /dev/null 2>&1
test $? -ne 0
assert "로케일 인자가 없으면 끊는다" $?

cat > "$CONFIG_DIR/pages.json" <<'JSON'
{ "page-a": { "ascPageId": "", "scenes": ["C1", "C2", "C3", "C4", "C5", "CX"] } }
JSON
python3 scripts/compose-cpp-screenshots.py --locale "$LANG_ID" > /dev/null 2>&1
test $? -ne 0
assert "모르는 장면은 끊는다" $?

cat > "$CONFIG_DIR/pages.json" <<'JSON'
{ "page-a": { "ascPageId": "", "scenes": ["C1", "C2", "C3", "C4", "C5"] } }
JSON
python3 scripts/compose-cpp-screenshots.py --locale "$LANG_ID" > /dev/null 2>&1
test $? -ne 0
assert "페이지당 6장이 아니면 끊는다" $?

cat > "$CONFIG_DIR/pages.json" <<'JSON'
{ "page-a": { "ascPageId": "", "scenes": ["C1", "C2", "C3", "C4", "C5", "C6"] } }
JSON
rm -f "$SOURCE_DIR/captions/cpp/C1.png"
python3 scripts/compose-cpp-screenshots.py --locale "$LANG_ID" > /dev/null 2>&1
test $? -ne 0
assert "캡션이 없으면 끊는다" $?

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
