---
description: 로컬라이제이션 리소스(.strings) 추가·수정 시 지킬 규칙 — 전 언어 동기화 짝과 번역 원칙
paths:
  - "Supports/Extensions/Resources/**"
  - "TodoCalendarApp/AppExtensions/Widget/Resources/**"
  - "TodoCalendarApp/Resources/Localize/**"
---

# 로컬라이제이션 규칙

지원 언어 31개 (en 원문 + 30개 번역: ko ja zh-Hans zh-Hant vi th es fr it pt-BR ca de nl sv da nb fi pl cs sk hu ru uk ro el hr tr id ms hi — #626). 번역 리소스는 3곳: 메인 `Supports/Extensions/Resources`(Localizable.strings), 위젯 `TodoCalendarApp/AppExtensions/Widget/Resources`(Localizable.strings), 앱 타겟 `TodoCalendarApp/Resources/Localize`.

앱 타겟 항목은 파일 3개를 담는다 — 각각 용도가 다르니 신규 문구를 아무 파일에나 넣지 말 것:
- `InfoPlist.strings` — 시스템 권한 요청 문구(카메라·마이크 접근 등).
- `Localizable.strings` — **AppIntents 라벨·다이얼로그**(`title`·`description`·`IntentDialog` 등). AppIntents 문구는 그 인텐트가 속한 타겟 자신의 번들에서 해석되므로, 공유 리소스인 `Supports/Extensions/Resources`에 넣으면 시스템이 못 찾는다 — 앱 타겟(`TodoCalendarApp`) 소속 인텐트는 반드시 여기. **#722에서 데인 함정**: AppIntents 메타데이터는 이 규칙을 몰라 다른 곳에 두면 조용히 원문(en)으로만 보이거나 라벨이 깨진다.
- `AppShortcuts.strings` — Siri 발화 phrase(`AppShortcutsProvider`).

## 1. 개발 중엔 en/ko만 — 번역은 #810으로 미룬다 (CLAUDE.md §1)

전 언어를 그 자리에서 번역하면 개별 작업이 번역에 발목잡힌다. 그래서 **개발 시점엔 `en`·`ko` lproj만 갱신하고, 나머지 29개 언어는 번역 대기 트래킹 이슈 #810에 미룬다.**

작업 시 이 셋을 같이 한다:
1. `en`·`ko` lproj에 키 추가·삭제·시그니처 변경 반영 (3개 리소스 위치 중 해당하는 곳).
2. #810 본문 "대기 목록"에 **현재 작업의 이슈 또는 PR 링크**를 한 줄 추가.
3. 커밋 전 `python3 scripts/check-localization-parity.py ko`로 en↔ko 파리티 0 위반 확인. 문법은 `plutil -lint <파일>`.

**미번역 언어에선 그 문구가 원문 키 그대로 노출된다** — `NSLocalizedString`은 키가 해당 lproj에 없을 때 en으로 fallback하지 않고 키 문자열을 돌려준다(`String+Extensions.swift`). 배포 전 #810 소진이 전제다.

### #810 처리 시점 (일괄 번역)

유저 지시로 #810을 처리할 때만 29개 언어를 채운다:

- 대기 키 목록의 정본은 `python3 scripts/check-localization-parity.py` (인자 없음 = 전 언어) 출력의 `missing keys`. #810 대기 목록의 링크는 번역 뉘앙스를 잡을 맥락 참조용.
- 번역 원칙은 아래 §2·§3.
- 전 언어 0 위반을 확인하고 #810 대기 목록을 비운 뒤 close.

### 서비스 이용 가이드 — lproj 의 후행 작업

앱이 인웹뷰로 여는 안내 페이지 원고는 이 레포가 아니라 `sudopark/TodoCalendar-Terms` 의
`guide/<언어코드>/` 에 있다 (언어 코드는 lproj 와 같고, 파일 7개는 전 언어 공통 이름).

- **lproj 가 먼저다.** 본문의 화면 라벨은 자유번역하지 않고 그 언어 lproj 값을 그대로 인용한다 —
  가이드가 앱 버튼을 다른 말로 부르면 독자가 그 버튼을 못 찾는다. 인용 소스는 lproj 3곳 전부다
  (Siri 발화문은 `AppShortcuts.strings`. 시스템이 `AppShortcutsProvider` 의 Swift 리터럴을
  키로 삼아 로컬라이즈하므로 영어로 남기지 않는다).
- **어떤 표현이 화면 라벨인지는 en↔ko 대조로 가른다.** 원고의 볼드는 UI 라벨(`**Convert to schedule**`)과
  서술 개념어(`**location**`)에 구분 없이 쓰여 표기만으로는 못 가른다. en 과 ko 가이드를 나란히 놓으면
  ko 는 ko lproj 값을 쓴 상태라 어느 볼드가 인용인지 드러나고, 그 ko 값을 lproj 에서 grep 하면 키가
  역추적된다 — 같은 키를 대상 언어 lproj 에서 찾으면 그게 정답 문구다.
- 링크 대상 파일·이미지 URL·헤딩 구조는 en 과 같게 두고, **헤딩 앵커만 번역된 헤딩을 따라간다**
  (`#foremost-event` → ko `#제일-중요한-이벤트`).
- 스크린샷은 `guide/images/` 영문 1벌을 절대 URL 로 전 언어가 공유한다 — 언어별로 다시 찍지 않는다.
- 검증: `python3 scripts/check-guide-parity.py <terms-repo-경로>` (언어 생략 = 전 언어) 0 위반.

## 2. 번역 원칙

- **도메인 3계층 용어 분리**: Event ⊃ {Todo, Schedule}는 언어마다 서로 다른 단어여야 한다 (`total::event::count`/`todo::count`/`schedule::count`가 리트머스). 예: de Ereignis/Aufgabe/Termin, fr événement/tâche/rendez-vous.
- **aiAgent 구획의 "Task"는 그 언어의 Todo 예약어 금지** — "명령(command)" 계열로 (예: sv Kommandot, de Befehl, fr commande). AI 명령 완료가 "할 일 완료"로 오독되는 충돌 방지.
- **위젯 명칭 일관**: D-day 위젯 관련 신규 문구는 그 언어의 기존 `widget.dday::name` 용어를 재사용 (언어별로 D-Day 차용/번역 클러스터가 다름 — zh-Hans 倒计时, de Countdown, tr Geri Sayım).
- **복수형**: stringsdict 미도입 — `%d minute(s)` 류는 각 언어의 단·복수 겸용 자연 표기. 슬라브어권 격변화 한계는 감수(#626 확정).
- **포맷 지정자**: multiset은 en과 일치. 어순상 재배치가 필요하면 positional(`%1$@`)로.

## 3. 날짜 포맷 키 — 번역 금지

`date_form::*` 23키와 `eventDetail.repeating.starttime:form`은 `DateFormatter.dateFormat`에 들어가는 Unicode TR35 패턴이다. 자연어로 번역하면 안 된다.

- 패턴 문자(y M d E H h m a) 보존. `24on_*` 키는 `H`, `24off_*`·`a_*` 키는 `h`(+`a`) 유지 — 24시간제 설정 분기라 시각 문자 교체 금지. 시각 구분자 `:` 유지.
- 날짜 순서는 로케일 관례: CJK·hu만 YMD, 나머지 DMY. sv는 숫자 전용 날짜만 ISO 8601(YMD) — 월명 포함 조합은 DMY.
- `starttime:form`은 전체 날짜 표기 — 로케일 관례에 따라 숫자형(`d/M/yyyy` 계열) 또는 월명형(`d MMM yyyy` 계열, en은 `MMM d, yyyy`). 같은 구성요소 키끼리 언어 내 순서·구분자 일관.
- 확신 없는 세부는 해당 로케일 `Locale` 표준 포맷(`yMd`·`MMMd` 스켈레톤 실측)이 정본.
