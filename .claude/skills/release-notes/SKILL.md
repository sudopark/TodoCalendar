---
name: release-notes
description: Use when writing the App Store "What's New" copy for a new app version — ko 원고 워싱과 en 원문 확정에 각각 걸린 두 승인 게이트, 29개 ASC 로케일 현지화 원칙, 업로드 전 검증과 fastlane 업로드를 다룬다. Triggers on "릴리즈 노트 쓰자", "이번 버전 변경내용 정리해줘", "새 버전 출시 문구 만들어줘". Does NOT trigger on 앱 내 이벤트 현지화(in-app-event 스킬), 버전과 무관한 메타데이터 수정(앱 설명·키워드·subtitle — fastlane/metadata/README.md 절차), 스크린샷 작업(fastlane/screenshots.md), 앱 내 문구 번역(.claude/rules/localization.md), 테스트 빌드 배포(test-deploy 스킬).
---

# Release Notes — 버전별 변경내용 원고·현지화

원고 정본은 `fastlane/metadata/<ASC 로케일>/release_notes.txt` 31개다. **en 이 나머지 29개 언어의 번역 소스**라, 순서가 이 스킬의 전부다 — ko 초안을 워싱해 승인받고, en 을 확정해 승인받고, 그 뒤에야 번역한다.

## 0. 착수 — 버전 짝 확인

- `Tuist/ProjectDescriptionHelpers/Project+AppVersion.swift` 의 `appVersion` ↔ 유저가 말한 버전이 같은지 본다. 다르면 어느 쪽이 맞는지 되묻는다.
- **`promotional_text.txt` 가 버전 번호를 본문에 박고 있으면 같이 갱신 대상이다** (현재 31개 로케일 전부 `3.0.0 — ` 로 시작한다). 짝을 놓치면 노트는 새 버전인데 프로모션 문구가 이전 버전을 광고한다.
  **갱신은 버전 번호 표기에 한정한다** — 나머지 문구는 유저 승인이 끝난 원고라 건드리지 않는다 (`fastlane/metadata/README.md`). 문구 자체를 새로 쓰기로 했으면 그것도 §1·§2 게이트를 태운다.
- `release_notes.txt` 는 버전마다 덮어쓴다. **과거 버전 원고 아카이브를 만들지 않는다** — 히스토리는 git log 가 갖는다.

## 1. 워싱 — 한글 초안 → ko 원고 (승인 게이트)

유저가 준 한글 초안은 개발자 시점 메모다. 옮겨 적지 말고 아래 기준으로 다시 쓴다:

- **톤은 `fastlane/metadata/ko/description.txt`** — 존댓말 평서문, 담백. 감탄·과장·이모지 없음.
- **화면 라벨은 ko lproj 값을 그대로 인용한다.** 자유번역 금지 — 노트가 앱 버튼을 다른 말로 부르면 독자가 그 버튼을 못 찾는다. 인용 소스는 lproj 3곳 전부다 (`.claude/rules/localization.md` 서두).
- **라벨을 정확히 못 찾으면 채우지 말고 되묻는다.** 초안 표현으로 ko lproj 를 부분 grep 하고, 안 걸리면 그 라벨이 있는 화면·플로우 이름으로 다시 찾는다. 그래도 못 찾으면 어느 화면의 어느 버튼인지 유저에게 묻는다. §3 은 승인된 en 을 앵커로 키를 역추적하지만 **§1 시점엔 그 앵커가 없다** — 기억으로 채우면 이 조항이 막으려는 실수를 여기서 재현한다.
- **내부 용어 금지** — 리팩토링·마이그레이션·유즈케이스·리포지토리 같은 구현 어휘는 유저 시점 결과로 바꾼다. "코드가 어떻게 달라졌나"가 아니라 "이제 뭘 할 수 있나".
- **초안에 없는 기능을 지어내지 않는다.** 초안이 모호하면 채우지 말고 유저에게 되묻는다.
- 항목 순서는 유저 체감 크기순. 자잘한 수정은 마지막 한 줄로 묶는다.

ko 원고를 보여주고 승인받는다. **승인 전에 en 을 쓰지 않는다.**

## 2. en 원문 (승인 게이트)

ko 승인본을 기준으로 en 을 쓴다. **여기가 급소다** — en 이 틀리면 29개 언어가 충실히 번역해 30배로 번진다 (#1015 가 그 사고였다: 가이드 en 이 앱 라벨 대신 일반명사를 써서 30개 언어가 전부 틀렸다).

- **화면 라벨은 en lproj 값 그대로.** ko 라벨을 영어로 옮기지 말고 en lproj 에서 찾아 쓴다.
- ko 를 직역하지 않는다 — `en-US/description.txt` 의 어휘·리듬에 맞춘다.
- **도메인 3계층(Event ⊃ Todo / Schedule)을 en 에서 먼저 정확히 가른다.** 여기서 뭉개면 29개 언어가 같이 뭉갠다 (localization.md §2).

승인받는다. **승인 전에 번역을 시작하지 않는다.**

## 3. 29개 언어

en 승인본을 소스로 나머지를 채운다. 디렉토리명은 lproj 코드가 아니라 **ASC 코드**다 — 6개가 다르고 매핑표는 `fastlane/metadata/README.md` 에 있다.

- 번역 원칙은 `.claude/rules/localization.md` §2 — 도메인 3계층 용어 분리, aiAgent 구획의 "명령" 계열, 위젯 명칭 일관.
- **각 언어의 화면 라벨은 그 언어 lproj 값을 grep 해 인용한다.** en 라벨로 en lproj 를 grep 해 키를 얻고, 같은 키를 대상 언어 lproj 에서 읽는다.
- 이 번역은 lproj 가 아니라 ASC 메타데이터다 — **번역 대기 트래킹 이슈 대상이 아니다.** 여기서 31개를 다 채운다. 미룰 자리가 없다.

## 4. 검증·업로드

```bash
python3 scripts/check-release-notes.py
```

31개 완비·4000자 상한·en 복사본(번역 누락) 여부를 본다. **0 위반이어야 다음으로 간다.**

원고를 커밋한 뒤(commit 스킬) 올린다. release_notes 전용 lane 은 없다 — 텍스트 메타데이터 lane 이 같이 올린다:

```bash
bundle exec fastlane ios upload_app_store_metadata
```

- 이 환경에서 처음 올리는 거면 `fastlane/metadata/README.md` 의 "업로드 전에 반드시 이 순서로" 를 먼저 탄다 — `deliver init` 기준선이 없으면 lane 이 스스로 중단한다.
- `ASC_KEY_ID`·`ASC_ISSUER_ID`·`ASC_KEY_CONTENT` 는 유저 환경에만 있다. **없으면 여기서 멈추고 유저에게 인계한다** — 실행을 흉내내지 않는다.
- 심사 제출은 콘솔에서 유저가 한다.

## Red Flags — 이 생각이 들면 STOP

| 생각 | 실제 |
|---|---|
| "ko 승인 기다리는 동안 en 초안이라도 잡아두자" | 게이트가 순서인 이유는 재작업이 아니라 번짐이다 — ko 가 바뀌면 en 도 다시 쓴다 |
| "ko 랑 en 을 한 번에 보여주면 왕복이 준다" | 유저가 둘을 같이 보면 ko 교정이 en 에 반영 안 된 채 넘어간다 |
| "라벨은 뜻만 맞으면 된다" | 노트가 앱 버튼을 다른 말로 부르면 독자가 못 찾는다 — lproj 값 그대로 |
| "나머지 언어는 트래킹 이슈에 미루자" | 그건 lproj 소관이다. ASC 메타데이터엔 미룰 자리가 없다 |
| "버그 수정뿐이라 쓸 게 없다" | 유저 체감 결과로 한 줄은 쓴다. 빈 노트는 업데이트 버전에서 로케일마다 심사 제출을 막는다 |

## 종료 기록 — skill_end

업로드를 마쳤거나 키가 없어 유저에게 인계하며 끝나는 시점에 `log-record.py skill_end` 를 1회 기록한다 (명령·compliance 규칙은 CLAUDE.md §1).
