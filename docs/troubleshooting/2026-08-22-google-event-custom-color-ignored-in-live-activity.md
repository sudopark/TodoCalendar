---
issue: "#934"
subdomain: ExternalCalendar
symptoms: [구글 이벤트 색상, 커스텀 색상 무시, 라이브액티비티 색, 캘린더 색으로 표시, colorId, googleEventColor]
resolution: fixed
---

# 구글 이벤트에 준 개별 색상이 라이브액티비티에서만 무시되고 캘린더 색으로 나온다

- **증상**: 구글 캘린더 이벤트에 개별 색상을 지정했는데 잠금화면 라이브액티비티에서만 그 색이 무시되고 캘린더 색으로 표시된다. 일별 리스트·상세 등 앱 내 다른 화면은 정상.

- **근본 원인**: 구글 이벤트 색 결정 규칙이 두 곳에 따로 구현돼 있었고 라이브액티비티 쪽이 열화판이었다.
  - 정본 `ViewAppearance.googleEventColor(_:_:)` — 이벤트 `colorId` 있으면 계정 팔레트 `events[colorId]`, 없으면 캘린더 `backgroundColorHex` → 팔레트 `calendars[tag.colorId]`
  - 열화판 `EventLiveActivityUsecaseImple.observedEvent(fromGoogle:)` — 캘린더 태그 `colorHex` 하나만 보고 `event.colorId`를 아예 안 봤다
  - 볼 수 없었던 이유: 팔레트(`GoogleCalendar.Colors`)가 `ViewAppearance`(MainActor presentation 객체)에만 적재됐다. `GoogleCalendarUsecaseImple.refreshColors`가 `appearanceStore`로만 흘려보내 SharedDataStore에 없었고, 라이브액티비티 usecase는 SharedDataStore만 읽어 colorId→hex 변환 수단이 없었다
  - 같은 뿌리의 2차 증상: 캘린더에 `backgroundColorHex` 없이 팔레트 `colorId`만 있으면 라이브액티비티가 캘린더 색조차 못 찾고 기본색으로 떨어졌다

- **해결**: 색 결정 규칙을 `GoogleCalendar.EventColorResolver`(Domain)로 추출해 `ViewAppearance`와 라이브액티비티가 같은 규칙을 호출하게 하고, 팔레트를 `ShareDataKeys.googleCalendarColors`로 SharedDataStore에도 적재했다. 계정 해제 시 `appearanceStore`와 SharedDataStore를 함께 정리한다.

- **기각 방향**: 라이브액티비티 usecase에 색 해석기를 주입해 `ViewAppearance`를 참조 — app 레이어 usecase가 MainActor presentation 객체에 의존해 단방향 의존성 위반
- **기각 방향**: `GoogleCalendar.Event`에 해석된 colorHex를 repository에서 미리 실어두기 — 색 규칙이 repository로 내려가고, 팔레트가 바뀔 때마다 이벤트 전체 재적재가 필요해진다

- **주의 — 계정 스코프는 소비자마다 다르다**: `ViewAppearance`는 calendarId만 받아 계정을 알 수 없으므로 calendarId 유일성을 전제로 태그를 평탄화한다. 이건 능력의 한계지 규칙이 아니다. `LiveActivityTarget`은 accountId를 싣고 있으므로 **그 계정의 태그·팔레트만** resolver에 넣어야 한다 — 평탄화하면 같은 calendarId를 여러 계정이 구독할 때(공유 캘린더·공휴일 캘린더) 임의의 계정 색이 이긴다. 수정 1차에서 이 격리를 잃었다가 되돌렸다.
