# 위젯 꾸미기 범위

> #1086 단계 3(위젯군 수평 확장)의 범위 정본. 2026-09-16 코드 정찰 + 유저 결정 반영.
> 구현이 끝나면 `docs/spec/widgets.md` §8 이 계약을 승계한다.
> 사진 배경은 DP-3.4 별건이라 제외했다.

꾸미기는 두 층으로 갈린다.

| 층 | 무엇 | 저장처 | 적용 범위 |
|---|---|---|---|
| **전역 배경색** | 배경색 하나 | `WidgetAppearanceSettings` | 전 위젯 기본값 |
| **스타일 배경색** | 같은 배경색 | `WidgetStyle` 봉투 | 그 스타일을 건 위젯 — 전역을 덮는다 |
| **표시 토글** | 위젯군별로 켜고 끌 요소 | `WidgetStyleSetting` payload | 그 위젯군 |

폰트와 **글자색**은 범위 밖이다 — 폰트는 위젯 캔버스가 작아 대응이 어렵고, 글자색은 안 보이는 위젯을 만들 수 있어서다 (유저 결정 2026-09-16).

## 1. 표시 토글

실제 뷰가 그리는 요소에서 뽑고 유저가 범위를 좁혔다. 렌더 지점은 해당 위젯 뷰 파일의 줄번호다.

| 위젯군 | 변형 | 항목 | 렌더 지점 |
|---|---|---|---|
| **Today** ✅완료 | `todaySummarySmall` 1 | 공휴일 이름 · 타임존 · 월/년 · 총 개수 · 할일 개수 · 일정 개수 | `TodayWidgetViews.swift:105~154` |
| **Month** | `monthSmall` 1 | 월 이름 · 요일 헤더 · 오늘 강조 · 이벤트 밑줄 | `MonthWidgetViews.swift:32·37·68·92` |
| **WeekEvents** | 7종 → **스타일 하나 공유** | 월 텍스트 · 요일 헤더 | `WeekEventsViews.swift:53·75` |
| **TodayAndNext** | `todayAndNextMedium` 1 | 타임존 | `TodayAndNextWidgetViews.swift:103-105` |
| **Foremost** | 홈 2 (small·medium) | "가장 중요한 일정" 라벨 | `ForemostWidgetViews.swift:80-84` |
| **AICommand** | 홈 1 (`aiCommandSmall`) | 설명 문구 | `AICommandWidgetViews.swift:48-50` |
| **EventList** | 3 (small·medium·large) | **없음** — 색만 | — |
| **DDay** | 홈 2 (small·medium) | **없음** — 색만 | — |
| **Composed** | 4 | **없음** — 하위 상속 + 색 | `ComposedWidgetViews.swift` 전체가 하위 뷰 `HStack` 합성 |

> **토글이 0이어도 꾸미기 대상이다.** 색이 스타일에 들어가므로 EventList·DDay·Composed 도 스타일을 갖고, 인스턴스마다 다른 색을 걸 수 있다.

### 빠진 것 (유저 결정 2026-09-16)

- WeekEvents 의 **오늘 강조**·**+N 표기**
- EventList 의 개별 토글 전부 (날짜 섹션 제목·시각·태그 색선·할일 완료 버튼·"일정 없음" 메시지)
- TodayAndNext 의 날짜 텍스트·이벤트 시각·미완료 할일 요약·빈 메시지
- Foremost 의 시각·태그 색선·완료 버튼·빈 상태 이모지
- DDay 의 반복 아이콘·날짜·시각·반복 문구

### WeekEvents 7변형은 스타일 하나를 공유한다

`oneWeekEvents` · `twoWeekEvents` · `threeWeekEvents` · `fourWeekEvents` · `currentMonthEvents` · `lastMonthEvents` · `nextMonthEvents`.

7종이 provider 하나(`WeekEventsWidgetTimelineProvider(range)`)와 뷰 하나(`WeekEventsWidgetView`)를 공유하고 생성자 인자로만 갈린다. 표시 항목도 같아서 유저가 7벌을 따로 편집할 이유가 없다 (유저 결정 2026-09-16).

> **DP-3.2 의 EventList 좌표 문제와 같은 형태다.** EventList 는 변형 3개가 kind 하나를 공유하고, WeekEvents 는 변형 7개가 스타일 하나를 공유한다. 편집 화면이 좌표 집합을 받게 여는 DP-3.0 설계(재가 완료)가 양쪽을 다 받는다.

## 2. 잠금화면 8변형 — 대상 밖

`ddayCircular` · `ddayRectangular` · `ddayInline` · `foremostInline` · `nextEventInline` · `nextEventRectangular` · `nextRemainRectangular` · `aiCommandCircular`

유저 결정으로 **꾸미기 대상이 아니다** (2026-09-16). `WidgetVariant.isCustomizable` 이 이 8종에 계속 `false` 로 남는다. 근거 셋:

- **색이 안 먹는다.** 시스템이 단색 렌더링을 강제한다 — `DDayWidgetViews.swift` 잠금화면 섹션 주석이 "시스템이 단색 렌더링을 적용하므로 색을 직접 지정하지 않는다"로 명시하고, 실제로 `.primary`/`.secondary` 만 쓴다.
- **배경 테마가 이미 제외돼 있다.** #721 FRAGO-7 의 의도된 제외이고 campaign 2항 범위 밖에 실려 있다.
- **토글할 요소가 없다시피 하다.** inline 계열은 텍스트 한 줄이 전부다.

### 다만 편집 시트의 "스타일" 줄은 못 가린다

위젯 하나(kind)에 Configuration 은 하나다. Foremost 를 `AppIntentConfiguration` 으로 전환하면 같은 kind 를 쓰는 `.accessoryInline` 도 그 Intent 를 갖고, AICommand 는 `.accessoryCircular` 가 같다. **잠금화면에 놓인 인스턴스의 편집 시트에도 "스타일" 줄이 뜬다.**

가릴 방법이 없다 — `parameterSummary` 의 `When` 은 파라미터 값끼리만 비교하고 family 는 파라미터가 아니다. 위젯 선언을 잠금화면용 Static / 홈용 AppIntent 로 가르는 것도 답이 아니다: kind 가 갈리면 이미 배치된 위젯이 죽어 A1 이 보장한 "기존 유저 것을 안 빼앗는다"가 깨진다.

**그대로 받는다** (유저 결정 2026-09-17) — 잠금화면은 애초에 꾸밀 항목이 없어 고르든 말든 모양이 안 바뀐다. provider 가 잠금화면 family 에서 스타일 좌표를 무시한다. DP-3.2 수용 위험으로 기록한다.

## 3. 색 — 배경색만, 위젯별로 정하고 전체로도 적용한다

색은 **배경색 하나**다. 글자색은 지금처럼 배경 밝기에 맞춰 자동으로 따라간다 (유저 결정 2026-09-16).

### 글자색을 안 여는 이유

- **위젯은 흘깃 보고 읽는 물건이다.** 배경색은 뭘 골라도 글자가 알아서 맞춰져서 못 망가뜨리는데, 글자색을 열면 검은 배경에 검은 글자를 만들 수 있다. 홈 화면에 상시 붙어 있는 물건이라 되돌리려면 앱을 열어 설정을 찾아가야 한다.
- **얻는 게 적다.** 배경색을 위젯별로 다르게 하는 것만으로 위젯마다 다른 모양이 나온다. 글자색으로 추가로 얻는 표현은 좁은데, 막으려면 대비 검사·경고 UI·프리셋 중 하나를 더 만들어야 한다.
- **나중에 열 수 있다.** 봉투에 필드를 더하면 된다. 반대로 한번 열면 닫기 어렵다 — 유저가 고른 색이 이미 저장돼 있다.

### 글자색은 배경에서 자동으로 나온다 (지금 구조 유지)

`Background.colorSet(_ systemIsLight:)`(`WidgetBackgroundStyle.swift:50-59`)가 배경색 밝기(`UIColor.isLight`)로 `DefaultLightColorSet` / `DefaultDarkColorSet` 을 고르고, 위젯 뷰가 거기서 `text0`·`text1`·`text2`·`accent` 를 꺼내 쓴다. 이 경로를 그대로 둔다.

### 전역이 기본, 스타일이 덮는다

| 걸음 | 내용 |
|---|---|
| 1 스타일 선택 | 인스턴스가 고른 스타일 — 지워졌으면 변형 기본 스타일 |
| 2 색 결정 | 그 스타일의 배경색 → 없으면 전역 배경색(`WidgetAppearanceSettings.background`) → 전역이 시스템이면 시스템 기본 |

스타일 경계를 넘어 필드만 폴백하면 안 된다 — 고른 스타일이 색을 안 걸었을 때 기본 스타일 색을 빌려오면 편집 화면·갤러리 프리뷰와 실제 위젯이 어긋난다.

"전체 적용"은 전역을 바꾸는 것이다. 지금은 전역 하나뿐이라 모든 위젯이 같은 배경인데, **위젯마다 다른 배경을 걸 수 있게 되는 것**이 이번에 느는 부분이다.

### 배경색은 스타일 봉투에 둔다 (확정)

배경색은 위젯군과 무관하게 똑같다. payload(`XxxStyleSetting`)마다 반복하는 대신 **스타일 봉투에 한 번만** 둔다.

```swift
public struct WidgetStyle {
    public let id: WidgetStyleId
    public var name: String?
    public var setting: any WidgetStyleSetting                    // 표시 토글
    public var background: WidgetAppearanceSettings.Background?   // nil 이면 전역을 따른다
}
```

> 봉투는 DP-3.0 FRAGO-2 로 비제네릭이 됐다 — 화면이 어느 변형인지를 런타임에 알아서 payload 타입을 컴파일 타임에 못 박을 수 없다.

DP-3.0 구조에서 편집 뷰모델은 payload 내용을 모르지만 봉투는 안다 — 배경색이 봉투에 있으면 **편집 뷰모델이 배경색 편집을 직접 다루고 색 편집 UI 를 한 벌만 만든다.** 위젯별 폼은 토글만 그린다.

`background` 가 Optional 인 것이 "전역 따름"을 표현한다. 표시 토글은 DP-2.3 FRAGO-1 로 non-Optional + `initial` 이 됐지만, 배경색은 **"미지정"이 의미를 갖는 제3의 상태**라 성격이 다르다. 저장 포맷은 안 깨진다 — 봉투 레코드에 Optional 필드가 느는 것이라 기존 저장값이 그대로 디코딩된다.

### DDay 는 배경색조차 글자에 반영이 안 된다

홈 변형까지 `.primary`/`.secondary` 고정이라 ColorSet 을 안 쓴다 (`DDayWidgetViews.swift`). 배경색만 열어도 **DDay ColorSet 정합은 필요하다** — 안 하면 DDay 만 배경을 바꿔도 글자가 안 따라온다.

### 구현된 계약은 `widgets.md` §8.3 이 정본이다

위 판단으로 DP-3.A 가 구현됐다. 해석 4단·렌더용 사본 채우기·편집 UI 한 벌·프리뷰 반영·DDay ColorSet 정합의 **실제 계약**은 [`widgets.md` §8.3 배경색 계약](widgets.md)에 등재돼 있다 — 이 문서는 그 결정에 이르는 범위 판단 기록이다.

### 계획과 충돌하지 않는다

campaign 2항 범위 밖의 "폰트 크기·텍스트 색 공통 축"은 **그대로 유효하다.** 텍스트 색은 여전히 안 열고, 배경색은 원래 있던 기능이다. 이번에 느는 것은 그 배경색을 위젯별로 갈 수 있게 하는 것뿐이라 조항 개정이 필요 없다.

## 4. 남은 분량

전 위젯군이 스타일을 갖는다 — 토글이 0인 위젯군도 색이 있어 payload 가 비지 않는다.

| 위젯군 | 토글 | 전환 필요 | 스타일 파라미터 |
|---|---|---|---|
| Month | 4 | `StaticConfiguration` → AppIntent 1개 | 필요 |
| WeekEvents | 2 (7변형 공유) | 7개 | 필요 |
| TodayAndNext | 1 | 이미 AppIntent | 파라미터 추가만 |
| EventList | 0 (색만) | 이미 AppIntent | 파라미터 추가만 |
| Foremost | 1 | 홈 2개 | 필요 |
| AICommand | 1 | 홈 1개 | 필요 |
| DDay | 0 (색만) | 이미 AppIntent | 파라미터 추가만 · 사진 배경은 별건 |
| Composed | 0 (색만 + 하위 상속) | 4개 | 필요 |

토글 총량은 9개다 (Today 6 은 완료분). 위젯군별 작업의 무게중심은 **전환 + 스타일 파라미터 + payload·폼 신설**이고, 색은 봉투에 있어 위젯군마다 따로 만들 게 없다.

## 5. 확정 사항 정리

| 항목 | 결정 | 일자 |
|---|---|---|
| 잠금화면 8변형 | 꾸미기 대상 밖 | 2026-09-16 |
| 폰트 | 범위 밖 | 2026-09-16 |
| 색 | **배경색만** — 위젯별 지정 + 전체 적용, 전역이 기본이고 스타일이 덮는다 | 2026-09-16 |
| 글자색 | 범위 밖 — 배경 밝기에서 자동으로 따라간다 | 2026-09-16 |
| 배경색 저장 위치 | `WidgetStyle` 봉투 (payload 아님) — 색 편집 UI 한 벌 | 2026-09-16 |
| WeekEvents 7변형 | 스타일 하나 공유 | 2026-09-16 |
| 기존 인스턴스 파라미터 | 병존 (흡수하지 않음) | 2026-09-15 |
| 편집 화면 구조 | 편집 뷰모델 1 + 위젯별 편집 폼 (브릿지) | 2026-09-16 · DP-3.0 재가 |

## 6. 남은 결정

없다. 단계 3 범위가 확정됐다 — campaign 8항(배열·요도)·9항(DP 목록)을 개정하고 DP 이슈를 다시 짠다.
