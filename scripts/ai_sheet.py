#!/usr/bin/env python3
"""AI 빠른 입력 시트가 캘린더 위에 떠 있는 장면을 조립한다.

카탈로그는 시트를 화면과 따로 찍지만, 실제로는 `showBottomSlide` 가 캘린더 위에 띄운다
(`Presentations/Scenes/Sources/BaseComponents.swift`). 그 모습을 여기서 만든다.
딤·코너는 프로덕션 값을 그대로 쓴다 — 딤은 검정 30%(`BottomSlideTransitions.swift`),
시트는 상단 좌우 코너 10pt(`BottomSlideView.swift`).
"""

from PIL import Image, ImageDraw

SCREEN = (1206, 2622)          # iPhone 17 @3x — 카탈로그 촬영 기본 규격. 앱스토어 스샷은 자기 규격을 넘긴다
DIM_RATIO = 0.3                # .black.withAlphaComponent(0.3)
SHEET_CORNER = 30              # topLeadingRadius/topTrailingRadius 10pt @3x
SHEET_PADDING = 48             # BottomSlideView 가 시트 콘텐츠에 주는 .padding() 16pt @3x
SAFE_AREA_BOTTOM = 102         # 홈 인디케이터 34pt @3x


def sheet_top(sheet):
    """시트가 시작하는 y — 콘텐츠 첫 행에서 시트 패딩만큼 거슬러 올라간 자리다.

    BottomSlideView 는 시트 위쪽을 투명 탭 영역으로 두는데 스냅샷은 그 영역을 캡처
    배경색으로 채워 내보내고, 그 색이 시트 배경색과 같아 경계가 픽셀로 안 보인다.
    언어마다 콘텐츠 높이가 달라 시트 상단도 함께 움직이므로 상수로 박으면 안 된다.
    """
    rgb = sheet.convert("RGB")
    width, height = rgb.size
    background = rgb.getpixel((0, 0))
    for y in range(height):
        row = rgb.crop((0, y, width, y + 1))
        single = row.getcolors(maxcolors=1)
        if single is None or single[0][1] != background:
            return max(0, y - SHEET_PADDING)
    raise SystemExit("✗ AI 시트 스냅샷이 배경색 한 가지뿐이다 — 촬영이 비었다")


def rounded_top_mask(size, radius):
    """상단 두 모서리만 둥근 마스크 — 하단 라운딩은 캔버스 밖으로 밀어 각지게 남긴다."""
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1 + radius), radius=radius, fill=255
    )
    return mask


def extended_to_bottom(sheet, height):
    """시트 아래에 자기 배경색 띠를 덧대 safe area 를 채운다."""
    extended = Image.new("RGB", (sheet.width, sheet.height + height), sheet.getpixel((0, sheet.height - 1)))
    extended.paste(sheet, (0, 0))
    return extended


def compose(background, sheet, screen_size=SCREEN):
    screen = background.convert("RGB").resize(screen_size, Image.LANCZOS)
    dimmed = Image.blend(screen, Image.new("RGB", screen_size, (0, 0, 0)), DIM_RATIO)

    cropped = sheet.convert("RGB")
    cropped = cropped.crop((0, sheet_top(cropped), cropped.width, cropped.height))
    ratio = screen_size[0] / cropped.width
    cropped = cropped.resize((screen_size[0], round(cropped.height * ratio)), Image.LANCZOS)

    # 시트 배경은 .ignoresSafeArea(edges: .bottom) 으로 홈 인디케이터까지 내려가고 콘텐츠는
    # 그 위에서 끝난다. 고정 프레임 스냅샷엔 그 여백이 없어 버튼이 화면 끝에 붙어 나온다.
    cropped = extended_to_bottom(cropped, SAFE_AREA_BOTTOM)

    if cropped.height >= screen_size[1]:
        raise SystemExit("✗ AI 시트가 화면을 다 덮는다 — 뒤 캘린더가 안 보인다")

    dimmed.paste(
        cropped, (0, screen_size[1] - cropped.height), rounded_top_mask(cropped.size, SHEET_CORNER)
    )
    return dimmed
