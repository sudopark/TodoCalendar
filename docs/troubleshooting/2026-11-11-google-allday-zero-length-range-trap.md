---
issue: "#1376"
subdomain: ExternalCalendar
symptoms: [GoogleCalendarEvent.init 크래시, EXC_BREAKPOINT, Range requires lowerBound <= upperBound, 구글 종일 이벤트, 시작일과 종료일이 같은 이벤트, calendarEventsPublisher]
resolution: deferred
---

# 시작일과 종료일이 같은 구글 종일 이벤트를 달력에 올리면 Range 생성에서 죽는다

- **증상**: Crashlytics `020cae740250af15d48732516061f335`. 3.1.2 에서 `GoogleCalendarEvent.init(_:in:isWritable:)` 이 EXC_BREAKPOINT 로 죽는다. 같은 유저가 그 이벤트가 조회 범위에 들어올 때마다 반복해서 죽는다 (7일 24건 / 4명).
- **근본 원인**: `GoogleCalendar.Event.init(origin:)` 이 종일 이벤트의 `start.date..<end.date` 를 검증 없이 담는다. 구글이 종료일을 시작일과 같게 주면(`endTimeUnspecified` 호환 종료 시각) 빈 범위가 들어오고, `GoogleCalendarEvent.init` 이 앱 내 종일 형식에 맞추려고 만드는 `range.lowerBound..<range.upperBound-1` (e502a2d5e, #379) 이 범위를 뒤집어 `Range` 생성이 트랩한다. swift 스크립트로 `1000.0..<1000.0` 에 같은 연산을 적용해 같은 fatal 을 재현했다.
- **해결**: `GoogleCalendar.Event.init(origin:)` 의 `.allDay` 분기에서 종료일이 시작일 이하이면 종료일을 그 타임존의 다음 날로 보정한다. 도메인에 길이 0인 종일 이벤트가 사라지므로 변환 쪽 `-1` 과 다른 소비처의 범위 계산이 전부 안전해진다. 수정은 #1376 으로 이관해 보류.
- **기각 방향**: `GoogleCalendarEvent.init` 에서 빈 범위만 가드 — 도메인에 빈 종일 범위가 남아 위젯·`EventTimeOnCalendar.clamped` 등 다른 소비처가 같은 값을 다시 만난다.
