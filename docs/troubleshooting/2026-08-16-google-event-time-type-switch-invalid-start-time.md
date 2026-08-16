---
issue: "#877"
subdomain: ExternalCalendar
symptoms: [Invalid start time, 구글 이벤트 종일 전환 400, 시간 있는 일정을 종일로 변경 실패, date dateTime 공존, patch 병합]
resolution: fixed
---

# 구글 이벤트의 시간 표현을 바꾸면 `Invalid start time` 400 이 뜬다

- **증상**: 시간이 있던 구글 이벤트를 종일로 바꿔 저장하면 `400 Invalid start time`. 보낸 페이로드는 `start: {date: "2026-08-15"}`, `end: {date: "2026-08-16"}` 로 단독으로는 유효한 종일 이벤트 스펙이다. 반대 방향(종일 → 시간 있음)도 같은 에러.

- **근본 원인**: `GoogleCalendar.EventOrigin.GoogleEventTime.asJson()` 이 nil 필드를 **키 자체를 빼는 방식**으로 직렬화했다. 구글의 `events.patch` 는 `start`/`end` 를 통째로 교체하지 않고 필드 단위로 병합하므로, 키가 빠지면 서버에 남아있던 이전 표현(`dateTime`·`timeZone`)이 살아남는다. 그 결과 최종 리소스가 `date` 와 `dateTime` 을 동시에 갖게 되고, 이 둘은 상호배타라 거부된다. 유효한 페이로드가 거부됐다는 사실 자체가 서버 잔존 필드와 병합됐다는 증거였다.

- **해결**: `asJson()` 이 `date`·`dateTime` 을 nil 일 때 **명시적 `NSNull()`** 로 내보낸다. 상호배타 쌍의 반대편이 항상 지워져 양방향 전환이 모두 성립한다. `GoogleEventTime.asJson()` 의 호출처는 `EventEditParams.asJson()` (편집 patch 페이로드) 하나뿐이라 다른 경로에 영향 없다. 회귀테스트는 `GoogleCalendarRepositoryImple_Tests.repository_updateEventToAllDay_sendsNullDateTime` / `repository_updateEventToTimed_sendsNullDate`.

- **기각 방향**: `events.update`(PUT) 전환 — `EventEditParams` 는 6개 필드만 보유해 전체 리소스 교체 시 반복 규칙·참석자·알림·회의정보가 소실된다.
