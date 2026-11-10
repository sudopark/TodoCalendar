---
issue: "#1377"
subdomain: Calendar
symptoms: [날짜 선택 다이얼로그 크래시, NSInternalInconsistencyException, Unable to set a visible month that is before the minimum or after the maximum date, UIDatePicker, 和暦, 불력, 비그레고리력, Calendar.current, SelectDayDialog]
resolution: fixed
---

# 기기 달력이 그레고리력이 아니면 날짜 선택 다이얼로그를 여는 순간 죽는다

- **증상**: Crashlytics `fe741015e1cc320abea6275cd5f79a02`. 3.1.1 부터 한 유저(iPhone 15 Pro Max, iOS 26.6.1)가 달력 화면에서 반복해서 죽는다. 브레드크럼이 매번 `CalendarPaperViewController` 에서 끝나는데, 다이얼로그가 `viewDidAppear` 전 레이아웃에서 죽어 화면 기록이 안 남기 때문이다. 시뮬레이터에 `AppleLocale = ja_JP@calendar=japanese` 를 넣고 상단 달력 아이콘을 탭해 같은 예외를 재현했다.
- **근본 원인**: `SelectDayDialogViewModelImple.initialCurrentSelectDate` 가 앱의 그레고리력 연·월·일을 `Calendar.current` 로 해석해 `Date` 를 만든다. 和暦이면 令和 2026년 = 서기 4044년이 되어 `UIDatePicker` 의 허용 범위를 벗어난다. `select(_:)` 의 역변환도 `Calendar.current` 라 반대 방향도 같은 혼용이다. 같은 모듈의 다른 변환(`CalendarViewModel`·`CurrentSelectDayModel+Component`)은 전부 `Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone` 이다.
- **해결**: 두 변환의 달력을 `Calendar(identifier: .gregorian)` 으로 고정하고 타임존은 기기 기본값으로 둔다. `DatePicker` 가 timeZone environment 없이 기기 타임존으로 날짜를 그리므로 변환도 같은 타임존이어야 같은 날짜가 오간다. PR #1380 으로 `release/3.1.3` 에 들어갔고 develop 에는 출시 후 백머지로 들어온다. `SelectDayViewModelTests` 는 기대값을 그레고리력으로 세운다. 그레고리력 시뮬레이터에선 수정 전후가 같이 통과하므로, 회귀 확인은 기기 locale 을 `ja_JP@calendar=japanese` 로 둔 시뮬레이터에서 돌린다.
- **기각 방향**: `DatePicker` 에 `.environment(\.calendar, gregorian)` 을 주입 — 和暦을 켠 유저에게 서기 달력을 강제하고, `select(_:)` 의 역변환 혼용은 그대로 남는다.
- **기각 방향**: 변환 타임존을 앱 설정 타임존으로 — 피커는 기기 타임존으로 그려서, 앱 타임존이 기기보다 앞서면 피커가 하루 전 날짜를 띄운다.
