---
name: crash-triage
description: Use when going through open Firebase Crashlytics crashes in this project to turn each into a bug issue — Crashlytics 크래시 목록 조회, 크래시 하나의 원인 규명, 규명 결과의 이슈화 시점. Triggers on "크래시리틱스 열린 크래시 봐줘", "크래시 정리해서 이슈로", "이 크래시 왜 나", Crashlytics issue id 나 콘솔 링크를 받았을 때. troubleshoot·superpowers:systematic-debugging 과 함께 invoke 하는 컴패니언. Does NOT trigger on CS 메일 답장(cs-reply 스킬), Crashlytics 없이 들어온 결함 리포트(troubleshoot 만), 이슈로 넘긴 크래시의 수정 구현(kickoff·implement).
---

# Crash Triage — Crashlytics 크래시를 버그 이슈로

**한 크래시의 종착은 bug 이슈 하나와 `deferred` 레코드 하나다. 수정 diff 는 내지 않는다.** 규명 절차는 troubleshoot 와 systematic-debugging 이 이끌고, 이 스킬은 Crashlytics 입력과 이슈 출력을 정한다.

## 입력 — Crashlytics MCP

- 모든 도구가 `appId` 를 받는다. 값은 `1:203166943134:ios:a4dcb694a4416a631cb88f` 다 (`TodoCalendarApp/Resources/GoogleService-Info.plist` 의 `GOOGLE_APP_ID`).
- 열린 크래시 목록은 `crashlytics_get_report` 로 받는다. 인자는 `report: "topIssues"`, `filter.issueErrorTypes: ["FATAL"]`, `filter.intervalStartTime`·`intervalEndTime` 이다. 기본 범위는 7일이고 최대 90일이다.
- 이벤트 상세(스택·breadcrumbs·기기·OS·버전)는 `crashlytics_list_events` 에 `filter.issueId` 를 주거나, 목록의 sampleEvent 이름을 `crashlytics_batch_get_events` 에 넣어 받는다.
- **`crashlytics_create_note`·`crashlytics_update_issue` 는 유저가 그 호출을 지시했을 때만 부른다.** 콘솔은 앱 밖이라 쓰면 되돌리기 어렵다. 이슈 링크를 노트로 달고 싶으면 유저에게 묻는다.
- 도구가 안 보이면 MCP 가 등록되지 않은 세션이다. 유저에게 `claude mcp add -s user firebase -- firebase mcp --only crashlytics` 를 알리고 멈춘다.

## 절차

1. **목록 보고** — 열린 크래시를 표로 보인다: issue id, 예외·시그니처, 7일 건수/유저 수, firstSeen–lastSeen 버전. 유저가 고른 건부터, 고르지 않으면 유저 수가 많은 건부터 하나씩 한다.
2. **규명** — troubleshoot ①②를 그대로 탄다. 원인은 앱 코드의 파일·심볼까지 좁히고, 확정은 실재현으로 한다. 재현 수단:
   - 순수 계산 트랩(Range·인덱스·강제 언래핑)은 swift 스크립트로 같은 식을 돌린다.
   - 기기 설정이 트리거(로케일·달력·지역)면 시뮬레이터에 `xcrun simctl spawn <udid> defaults write -g AppleLocale <값>` 을 넣고 앱을 다시 띄운다. **끝나면 같은 명령으로 원래 값을 되돌린다** — 원래 값은 넣기 전에 `defaults read -g AppleLocale` 로 받아 둔다. 시뮬레이터 사용은 세션당 한 대다.
   - 재현을 못 했으면 이슈 본문 "재현" 절에 못 했다고 쓰고, 원인을 코드 근거까지로 적는다.
3. **이슈** — issue 스킬로 `bug` 라벨 이슈를 만들고 보드 `Todo` 로 둔다. 본문은 아래 순서다.
4. **레코드** — troubleshoot ③ 레코드를 `resolution: deferred`·`issue: "#N"` 으로 쓰고 INDEX 에 한 줄 넣는다. 레코드와 INDEX 는 commit 스킬로 `[#N]` 커밋을 만들어 지금 체크아웃한 브랜치에 바로 넣는다 — 수정 브랜치가 따로 없어서, 커밋하지 않으면 레코드를 잃는다. 푸시는 유저 지시를 따른다.
5. 다음 크래시로 간다. 다 끝나면 만든 이슈 번호 목록으로 보고한다.

## 이슈 본문 — 순서 고정

1. **결론 문단** — 증상(언제 죽나), 원인(파일·심볼과 기전), 수정 방향 한 문장.
2. **관측** — Crashlytics 콘솔 링크(`https://console.firebase.google.com/project/todocalendar-1707723626269/crashlytics/app/ios:com.sudo.park.TodoCalendarApp/issues/<issue id>`), 예외 이름, 첫 발생 버전, 기간·건수·유저 수, 기기·OS, 스택의 앱 프레임 경로.
3. **재현** — 실제로 돌린 수단과 결과. 못 했으면 못 했다고.
4. **원인** — 파일 경로와 심볼, 같은 모듈의 올바른 관례와의 대조.
5. **수정 방향** — troubleshoot ② 에서 고른 하나.
6. **레코드 경로** — `docs/troubleshooting/<파일>.md`.
