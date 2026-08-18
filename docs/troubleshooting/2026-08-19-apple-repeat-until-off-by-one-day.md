---
issue: "#917"
subdomain: ExternalCalendar
symptoms: [애플 반복 종료일 하루 뒤, UNTIL 하루 밀림, EKRecurrenceEnd endDate, 반복 종료 타임존]
resolution: fixed
---

# 애플 캘린더 반복 일정의 종료일이 앱 상세에서 하루 뒤로 보인다

- **증상**: 애플 캘린더에서 종료일을 9/30로 설정한 시간 지정 반복 일정이, 앱의 이벤트 상세 반복 텍스트와 반복 옵션 선택 화면에서 10/1로 표시된다. 캘린더 화면의 회차 전개는 정상(EventKit 이 펼치므로 애플 기준).
- **근본 원인**: 애플은 반복 종료를 *날짜*로 저장하지만 `EKRecurrenceEnd.endDate` 는 그걸 UTC 하루 끝 instant 로 돌려준다. `EKRecurrenceRule.toRRuleString()` 이 그 instant 를 UTC 로 그대로 직렬화하고, 표시 자리(`RRule.endOptionText` · `RepeatEndTime`)가 파싱된 instant 를 앱 타임존에 다시 찍으면서 KST 에서 날짜가 넘어갔다.
- **해결**: `RRule.reanchoringUTCDayEndUntil(to:)` 로 UNTIL 이 UTC 하루 끝 경계일 때만 그 날짜를 앱 타임존의 하루 끝으로 재앵커링한다. 경계는 `23:59:59Z` 와 다음날 `00:00:00Z` 둘 다 관측 가능해 1초 당겨 같은 날짜로 모은다. 애플 상세의 rrule 해석 자리 두 곳(`editableRepeating` · `repeatText` 잠긴 규칙 경로)에서만 호출해 구글 경로는 건드리지 않는다.
- **기각 방향**: 공유 표시 코드(`RRule.endOptionText`)에서 날짜 부분만 떼어 쓰기 — 구글은 UNTIL 을 실제 instant 로 주는 경우가 있어 같이 틀어진다
- **기각 방향**: 경계 판정 없이 항상 재앵커링 — 앱이 저장한 로컬 instant 가 음수 오프셋 타임존에서 매 저장마다 하루씩 밀린다
