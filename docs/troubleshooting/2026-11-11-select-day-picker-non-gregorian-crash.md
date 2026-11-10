---
issue: "#1377"
subdomain: Calendar
symptoms: [날짜 선택 다이얼로그 크래시, NSInternalInconsistencyException, Unable to set a visible month that is before the minimum or after the maximum date, UIDatePicker, 和暦, 불력, 비그레고리력, Calendar.current, SelectDayDialog]
resolution: deferred
---

# 기기 달력이 그레고리력이 아니면 날짜 선택 다이얼로그를 여는 순간 죽는다

- **증상**: Crashlytics `fe741015e1cc320abea6275cd5f79a02`. 3.1.1 부터 한 유저(iPhone 15 Pro Max, iOS 26.6.1)가 달력 화면에서 반복해서 죽는다. 브레드크럼이 매번 `CalendarPaperViewController` 에서 끝나는데, 다이얼로그가 `viewDidAppear` 전 레이아웃에서 죽어 화면 기록이 안 남기 때문이다. 시뮬레이터에 `AppleLocale = ja_JP@calendar=japanese` 를 넣고 상단 달력 아이콘을 탭해 같은 예외를 재현했다.
- **근본 원인**: `SelectDayDialogViewModelImple.initialCurrentSelectDate` 가 앱의 그레고리력 연·월·일을 `Calendar.current` 로 해석해 `Date` 를 만든다. 和暦이면 令和 2026년 = 서기 4044년이 되어 `UIDatePicker` 의 허용 범위를 벗어난다. `select(_:)` 의 역변환도 `Calendar.current` 라 반대 방향도 같은 혼용이다. 같은 모듈의 다른 변환(`CalendarViewModel`·`CurrentSelectDayModel+Component`)은 전부 `Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone` 이다.
- **해결**: 두 변환을 앱 관례대로 그레고리력 + 앱 타임존으로 바꾼다. `DatePicker` 는 절대 시각을 받으므로 기기 달력은 그대로 둔다. 수정은 #1377 로 이관해 보류.
- **기각 방향**: `DatePicker` 에 `.environment(\.calendar, gregorian)` 을 주입 — 和暦을 켠 유저에게 서기 달력을 강제하고, `select(_:)` 의 역변환 혼용은 그대로 남는다.
