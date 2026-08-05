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

## 1. 전 언어 동기화 짝 (CLAUDE.md §1)

**en에 키를 추가·삭제·시그니처 변경하면 나머지 30개 언어 lproj를 같은 커밋 흐름에서 갱신한다.** en/ko만 갱신하고 끝내면 29개 언어가 즉시 stale이 된다.

검증: `python3 scripts/check-localization-parity.py` (인자 없으면 전 언어) — 키 세트·포맷 지정자 multiset·중복 키를 en과 대조. 커밋 전 0 위반 확인. 문법은 `plutil -lint <파일>`.

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
