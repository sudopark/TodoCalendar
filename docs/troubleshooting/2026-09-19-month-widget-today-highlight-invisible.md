---
issue: "#1112"
subdomain: Calendar
symptoms: [오늘 강조, selectedDayBackground, 다크모드, 배경에 묻힘, Month 위젯, backgroundColor 미적용]
resolution: fixed
---

# Month 위젯 오늘 강조가 배경과 같은 계열로 나와 안 보인다

- **증상**: Month 위젯에서 오늘 날짜 강조가 보이지 않는다. 다크모드에서 특히 두드러진다 — 어두운 배경에 어두운 글자가 찍힌다. 홈 위젯·스타일 편집 프리뷰·갤러리 썸네일 셋 다 같다.
- **근본 원인**: `SingleMonthView.dayTextLabel` 이 `backgroundColor` 를 계산만 하고 `.background(...)` 를 걸지 않았다. 배지 판이 아예 안 그려지고 글자색만 `selectedDayText` 로 반전되는데, 그 값은 배경 밝기에서 파생된 ColorSet 소속이라 배경과 같은 계열이 된다. 다크셋 `selectedDayText = 0x1a153d`(어두운 남색) → 어두운 배경에 묻히고, 라이트셋 `= white` → 흰 배경에 묻힌다. **모드 무관한 결함이고 다크모드에서 먼저 눈에 띈 것뿐이다.**
- **해결**: 계산한 강조색을 `RoundedRectangle(cornerRadius: Metric.Radius.chip).fill(...)` 로 실제로 칠한다. 형제인 앱 본체 달력 `CalendarScenes/Sources/Month/MonthView.swift:362` 가 같은 형태를 쓴다. 단 평일 칸은 `.clear` 로 둔다 — 앱 본체와 달리 위젯은 셀이 빽빽해 `dayBackground` 를 칸마다 그리면 다크모드에서 격자가 드러난다.
- **기각 방향**: 다크모드용 강조 글자색을 따로 지정 — 배지가 없는 상태를 전제한 증상 패치이고, 라이트모드(흰 배경에 흰 글자)는 그대로 남는다.

세 경로(홈 위젯·편집 프리뷰·갤러리 프리뷰)에서 동시에 났다는 게 provider 가 아니라 뷰 공통 문제라는 신호였다. #1065 에서 Today·Month 뷰를 WidgetScenes 로 내릴 때부터 있던 결함이다.
