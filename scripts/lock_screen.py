#!/usr/bin/env python3
"""잠금화면 장면을 조립한다 — 벽지 + 제일중요(인라인) + 시계 + 다음/남은 위젯 + 라이브 액티비티.

카탈로그가 찍어주는 건 위젯·라이브 액티비티 조각뿐이라, 그걸 얹을 잠금화면은 여기서 만든다.
`compose-appstore-screenshots.py` 의 `home_screen()` 이 홈화면판으로 같은 일을 한다.

**시계 숫자 말고는 여기서 텍스트를 그리지 않는다** — Pillow 로는 31개 언어(데바나가리·타이·CJK)를
한 TTF 로 못 그린다. 로케일별 문구는 전부 스냅샷 조각이 들고 온다.

accessory 위젯은 실제 잠금화면에서 배경 없이 벽지 위에 얹힌다. 스냅샷은 불투명 검정 배경으로
나오므로(captureSnapshotPair 에 투명 옵션이 없다) lighten 으로 합성해 검정을 떨군다.
라이브 액티비티만 실제로도 어두운 카드라 그대로 얹는다.
"""

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

SCREEN = (1206, 2622)                 # iPhone 17 @3x — 카탈로그 촬영 규격과 같다
CLOCK_FONT = "/System/Library/Fonts/SFNS.ttf"
CLOCK_SIZE = 290

# 카드는 폰 화면 위쪽을 잘라내고 담는다 — 인라인이 250 에 있으면 그 크롭선에 걸려 사라진다.
# 스택 전체를 내려 잘림선 아래로 보낸다.
INLINE_TOP = 430                      # 시계 위 인라인 슬롯
CLOCK_TOP = 500
ROW_TOP = 880                         # 시계 아래 좌우 2열
ROW_GAP = 40
# 라이브 액티비티는 실제로 화면 하단(손전등·카메라 버튼 위)에 뜬다
LIVE_ACTIVITY_BOTTOM = 2280
SIDE_MARGIN = 90

WALLPAPER_TOP = (26, 32, 58)
WALLPAPER_BOTTOM = (72, 58, 96)
CORNER_RATIO = 0.16

# 위젯 뷰의 Image("small_icon") 은 Bundle.main 을 뒤지는데, 스냅샷은 앱을 호스트로 돌고
# 앱 번들엔 이 에셋이 없다(위젯 확장 번들 소유). 그래서 스냅샷엔 24pt 빈자리만 남는다.
# 실기기에는 뜨는 아이콘이라, 실제와 같게 보이도록 합성 단계에서 원본 에셋을 그 자리에 얹는다.
SMALL_ICON = Path(__file__).resolve().parent.parent / (
    "TodoCalendarApp/AppExtensions/Widget/Resources/Assets.xcassets/"
    "small_icon.imageset/appIcon-origin-dark-128.png"
)
ICON_SLOT_POINTS = 24          # 프로덕션 뷰의 .frame(width: 24, height: 24)
ACCESSORY_SCALE = 3            # @3x 촬영


def wallpaper(size):
    width, height = size
    image = Image.new("RGB", size)
    for y in range(height):
        ratio = y / (height - 1)
        row = tuple(
            round(WALLPAPER_TOP[c] + (WALLPAPER_BOTTOM[c] - WALLPAPER_TOP[c]) * ratio)
            for c in range(3)
        )
        image.paste(row, (0, y, width, y + 1))
    return image


def draw_clock(canvas, text="9:41"):
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(CLOCK_FONT, CLOCK_SIZE)
    box = draw.textbbox((0, 0), text, font=font)
    x = (canvas.width - (box[2] - box[0])) // 2 - box[0]
    draw.text((x, CLOCK_TOP), text, font=font, fill=(255, 255, 255))


def scaled(source, width):
    piece = source.convert("RGB")
    ratio = width / piece.width
    return piece.resize((width, round(piece.height * ratio)), Image.LANCZOS)


def first_text_band(piece, threshold=40):
    """가장 위쪽 밝은 픽셀 띠 — 아이콘이 들어갈 타이틀 행이다."""
    gray = piece.convert("L")
    rows = [y for y in range(gray.height)
            if max(gray.crop((0, y, gray.width, y + 1)).getdata()) > threshold]
    if not rows:
        return None
    top = rows[0]
    bottom = top
    for y in rows:
        if y - bottom > 4:
            break
        bottom = y
    return top, bottom


def with_small_icon(piece):
    """비어 있는 아이콘 슬롯에 실제 에셋을 얹는다."""
    band = first_text_band(piece)
    if band is None or not SMALL_ICON.exists():
        return piece

    size = ICON_SLOT_POINTS * ACCESSORY_SCALE
    with Image.open(SMALL_ICON) as source:
        icon = source.convert("RGBA").resize((size, size), Image.LANCZOS)

    out = piece.convert("RGBA")
    top = (band[0] + band[1]) // 2 - size // 2
    out.alpha_composite(icon, (0, max(0, top)))
    return out.convert("RGB")


def paste_vibrancy(canvas, piece, position):
    """검정 배경을 떨구고 밝은 픽셀만 남긴다 — 실제 accessory 위젯의 vibrancy 와 같은 모양."""
    left, top = position
    region = canvas.crop((left, top, left + piece.width, top + piece.height))
    canvas.paste(ImageChops.lighter(region, piece), (left, top))


def paste_card(canvas, piece, position):
    radius = round(min(piece.size) * CORNER_RATIO)
    mask = Image.new("L", piece.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, piece.width - 1, piece.height - 1], radius, fill=255)
    canvas.paste(piece, position, mask)


def compose(foremost, next_event, next_remain, live_activity):
    canvas = wallpaper(SCREEN)
    usable = SCREEN[0] - SIDE_MARGIN * 2

    inline = scaled(foremost, round(usable * 0.72))
    paste_vibrancy(canvas, inline, ((SCREEN[0] - inline.width) // 2, INLINE_TOP))

    draw_clock(canvas)

    column = (usable - ROW_GAP) // 2
    left_piece = with_small_icon(scaled(next_event, column))
    right_piece = scaled(next_remain, column)
    row_height = max(left_piece.height, right_piece.height)
    paste_vibrancy(canvas, left_piece, (SIDE_MARGIN, ROW_TOP))
    paste_vibrancy(canvas, right_piece, (SIDE_MARGIN + column + ROW_GAP, ROW_TOP))

    activity = scaled(live_activity, usable)
    paste_card(
        canvas, activity,
        ((SCREEN[0] - activity.width) // 2, LIVE_ACTIVITY_BOTTOM - activity.height)
    )

    return canvas
