---
name: in-app-event
description: Use when filling in an App Store in-app event's localized copy and images — 절차·순서·게이트는 본문이 정한다. Triggers on "앱 내 이벤트 현지화하자", "인앱 이벤트 이미지 만들어줘", "인앱 이벤트 텍스트 올려줘". Does NOT trigger on 도메인 이벤트(Todo·Schedule) 편집, 버전별 변경내용(release-notes 스킬), 앱 설명·키워드 등 버전 무관 메타데이터(fastlane/metadata/README.md), 앱스토어 스크린샷(fastlane/screenshots.md), 앱 내 문구 번역(.claude/rules/localization.md), 이벤트 생성·일정·territory 설정(ASC 콘솔에서 유저가 한다).
---

# In-App Event — 앱 내 이벤트 현지화·업로드

`deliver` 는 In-App Events 를 모른다. ASC API 를 직접 때리는 스크립트 셋을 순서대로 엮는 것이 이 스킬의 전부다.

**이 스킬이 만지는 것은 로케일 텍스트·뱃지·이미지 셋뿐이다.** 이벤트 생성, 일정(`territorySchedules`), `deepLink`·`purpose`·`priority` 는 유저가 ASC 콘솔에서 한다.

## 0. 준비 — 실행 환경과 자격증명

- ruby PATH 는 [`docs/appstore-connect-operations.md`](../../../docs/appstore-connect-operations.md) §1 이 정본이다. 명령마다 `export PATH="/opt/homebrew/opt/ruby/bin:$PATH"` 를 같은 줄에 실어 보낸다 — 에이전트 셸은 명령마다 새로 떠서 앞선 `export` 가 넘어가지 않는다.
- 자격증명은 스크립트가 `secret/asc-api-key.json` 에서 읽는다 (형식은 [`secret/README.md`](../../../secret/README.md), 발급·권한은 ops 문서 §2). 환경변수 셋이 차 있으면 그쪽이 우선한다.
- **파일도 환경변수도 없으면 인증이 필요한 절에서 멈추고 유저에게 인계한다** — 실행을 흉내내지 않는다.

**자격증명이 필요한 절은 §1·§3·§5 뿐이다.** §2(원고·번역)와 §4(촬영·합성)는 파일만 만들어 네트워크를 안 탄다 — 키가 없어도 거기까지는 진행하고, 업로드만 남겨 인계한다.

## 1. 대상 이벤트 확정

인자로 이벤트를 받았으면 그대로 쓴다. 없으면 조회해 목록을 제시하고 추천한다:

```sh
bundle exec ruby scripts/asc-in-app-event.rb list
```

- `eventState` 가 `PUBLISHED`·`PAST`·`ARCHIVED` 면 스크립트가 경고한다 — **게시된 이벤트를 덮어쓰는 게 맞는지 유저에게 확인받는다.**
- 목록이 비면 콘솔에서 먼저 만들라고 안내하고 멈춘다. 이 스킬은 이벤트를 만들지 않는다.
- 원고·설정을 담을 자리를 만든다: `fastlane/in_app_events/<event_id>/`. `event_id` 는 사람이 읽는 슬러그이고(예: `2026-03-spring`), ASC 이벤트 id 는 `event.json` 의 `ascEventId` 에 적는다.

## 2. 원고 — 승인 게이트 2개

원고 정본은 `fastlane/in_app_events/<event_id>/<ASC 로케일>/{name,short_description,long_description}.txt` 31벌이다. **en 이 나머지 29개 언어의 번역 소스**라 순서가 전부다.

| 필드 | 상한 | 노출 위치 |
|---|---|---|
| `name.txt` | 30자 | 이벤트 카드·상세 |
| `short_description.txt` | 50자 | 이벤트 카드 |
| `long_description.txt` | 120자 | 이벤트 상세 페이지 |

### 2-1. ko 원고 (승인 게이트)

유저가 한국어로 셋을 준다. **옮겨 적지 말고 상한에 맞춰 워싱한다:**

- 톤은 `fastlane/metadata/ko/description.txt` — 존댓말 평서문, 담백. 감탄·과장·이모지 없음.
- **화면 라벨은 ko lproj 값을 그대로 인용한다.** 자유번역 금지 — 이벤트가 앱 버튼을 다른 말로 부르면 독자가 그 버튼을 못 찾는다. 인용 소스는 lproj 3곳 전부다 (`.claude/rules/localization.md` 서두).
- **라벨을 정확히 못 찾으면 채우지 말고 되묻는다.** 초안 표현으로 ko lproj 를 부분 grep 하고, 안 걸리면 그 라벨이 있는 화면·플로우 이름으로 다시 찾는다. 그래도 못 찾으면 어느 화면의 어느 버튼인지 유저에게 묻는다 — 기억으로 채우면 이 조항이 막으려는 실수를 여기서 재현한다.
- 상한이 빠듯하다. **줄이느라 유저가 말한 혜택·조건을 지어내거나 빼지 않는다** — 못 줄이겠으면 유저에게 무엇을 뺄지 되묻는다.

ko 원고를 보여주고 승인받는다. **승인 전에 en 을 쓰지 않는다.**

### 2-2. en 원문 (승인 게이트)

**여기가 급소다** — en 이 틀리면 29개 언어가 충실히 번역해 30배로 번진다 (#1015 가 그 사고였다).

- **화면 라벨은 en lproj 값 그대로.** ko 라벨을 영어로 옮기지 말고 en lproj 에서 찾아 쓴다.
- ko 를 직역하지 않는다 — `fastlane/metadata/en-US/description.txt` 의 어휘·리듬에 맞춘다.
- **도메인 3계층(Event ⊃ Todo / Schedule)을 en 에서 먼저 정확히 가른다.** 여기서 뭉개면 29개 언어가 같이 뭉갠다.

승인받는다. **승인 전에 번역을 시작하지 않는다.**

### 2-3. 29개 언어

- 디렉토리명은 lproj 코드가 아니라 **ASC 코드**다 — 6개가 다르고 매핑표는 `fastlane/metadata/README.md`.
- 번역 원칙·라벨 역추적 절차는 release-notes 스킬 §3 과 같다 (정본은 `.claude/rules/localization.md` §2). 여기서 재서술하지 않는다.
- **각 언어의 화면 라벨은 그 언어 lproj 값을 grep 해 인용한다.** en 라벨로 en lproj 를 grep 해 키를 얻고, 같은 키를 대상 언어 lproj 에서 읽는다.
- **번역 대기 트래킹 이슈 대상이 아니다.** 그건 lproj 소관이고, ASC 메타데이터엔 미룰 자리가 없다. 여기서 31개를 다 채운다.
- 상한 초과는 `--dry-run` 이 위반을 전량 모아 보여준다. 언어별로 짧게 다시 쓴다.

## 3. 뱃지

7종 중 이벤트 성격에 맞는 것을 제시하고 유저가 고른다:

`LIVE_EVENT` · `PREMIERE` · `CHALLENGE` · `COMPETITION` · `NEW_SEASON` · `MAJOR_UPDATE` · `SPECIAL_EVENT`

```sh
bundle exec ruby scripts/asc-in-app-event.rb set-badge <ascEventId> <BADGE>
```

## 4. 이미지

**합성 규칙의 정본은 유저의 문서다:**
`/Users/sudo.park/Documents/sudo/인디앱 개발/To-do Calendar/공통지침-인앱이벤트-이미지-합성-파이프라인.md`

레포에 복사본을 두지 않는다 — 가이드 레포와 같은 처리이고, 복사하면 짝이 어긋난다.

**정본과 한 군데 다르다**: 지침 §4 는 "라이선스 문제 없는 목업, 라운드 사각형+노치를 코드로 그려도 충분" 이라 하지만, 이 파이프라인은 `scripts/compose-appstore-screenshots.py` 선례를 따라 **애플 공식 베젤**을 쓴다 (마케팅 가이드라인 허용 범위, non-transferable 라이선스라 레포에 커밋하지 않고 캐시에 받아 쓴다). **이미지 작업을 시작할 때 그 문서를 연다.** 이벤트마다 바뀌는 장면·카피·더미 데이터는 유저가 "[이벤트별 지침] 스크린샷 명세"로 따로 준다.

### 4-1. 장면 정하기

이벤트별 명세가 지정한 장면이 `snapshot-catalog/` 에 이미 있으면 그걸 쓴다. 없으면 **카탈로그 스냅샷 테스트를 신설한다** (app-catalog 스킬 §1·§2 — 더미 텍스트는 하드코딩하지 말고 `CatalogStrings.strings` 나 프로덕션 경로로).

`event.json` 스키마 정본은 [`fastlane/in_app_events/README.md`](../../../fastlane/in_app_events/README.md) 다 — 스크립트가 읽는 필드와 기본값이 거기 적혀 있다.

장면 값은 세 형태(카탈로그 경로 / 앱스토어 원본 / 조립)이고 카드는 기기를 여러 대 세울 수 있다 — 형태·조각·기본값은 전부 그 README 소관이다. **`captureSuites` 는 카탈로그를 쓰는 장면의 스위트를 다 덮어야 한다** — 안 덮으면 스크립트가 촬영 전에 끊는다 (안 끊으면 이전 실행이 남긴 다른 언어·다른 기기 규격 파일이 조용히 섞인다).

### 4-2. 촬영·합성

```sh
scripts/capture-event-screenshots.sh <event_id> ko          # 먼저 한 언어로 확인
scripts/capture-event-screenshots.sh <event_id> --all       # 31개 언어 (오래 걸린다)
python3 scripts/compose-event-images.py --event <event_id> --all-locales
```

- 촬영은 언어당 스위트 수만큼 `xcodebuild test` 를 돌린다. **31개 언어는 시간 단위다** — 백그라운드로 돌리고, 먼저 ko 한 언어로 결과를 유저에게 보여 방향을 확정한 뒤 전 언어로 간다.
- **하단 1/3 은 배치가 보장한다** — 목업 하단이 `CARD_DEVICE_BOTTOM`(680)에 고정되고 위로만 자라므로 `cardDeviceHeight` 를 키워도 침범하지 않는다. 합성기는 그 결과를 산출물 픽셀로 재확인할 뿐이다(배치 코드가 바뀌었을 때를 위한 방어).
- 실제로 끊기는 건 셋이다 — 좌우 96px 침범(그려진 픽셀 기준), 기울임 5~10도 이탈, 알파 잔존. 좌우 침범은 기기가 한 대면 `cardDeviceHeight`, 여러 대면 `cardFlankSpread` 나 `cardFlankScale` 을 줄여 해소한다.

### 4-3. 기계가 못 보는 자가 검증

`compose-event-images.py` 의 `verify()` 는 해상도·알파·산출물 트리만 본다. **나머지는 이미지를 열어서 확인한다:**

- [ ] **홍보 문구·로고 워터마크 없음** — 카피는 App Store 가 카드 하단에 얹는다 (지침 §2-5·§3-4)
- [ ] **한 이미지 안 언어 혼용 없음** — ko 이미지에 영어 UI 가 섞이지 않았나
- [ ] **더미 데이터에 실명·실제 개인 일정·실존 회사명 없음**
- [ ] **새 이벤트가 코드 수정 0 으로 도는가** — `event.json` 만 바꿔 한 번 돌려본다 (지침 §6 마지막 항)
- [ ] **앱에 없는 기능을 연출하지 않았나** — 이벤트별 명세에 적혀 있어도 **실제 빌드에 없으면 제외하고 유저에게 보고한다.** 오해 소지 메타데이터는 심사 리젝 사유다

## 5. 업로드

**텍스트가 먼저다** — 이미지는 로케일에 매달리므로 부모가 없으면 못 올린다.

```sh
bundle exec ruby scripts/asc-in-app-event.rb push-text   --event <event_id> --all-locales --dry-run
bundle exec ruby scripts/asc-in-app-event.rb push-text   --event <event_id> --all-locales
bundle exec ruby scripts/asc-in-app-event.rb push-images --event <event_id> --all-locales --dry-run
bundle exec ruby scripts/asc-in-app-event.rb push-images --event <event_id> --all-locales
```

- `--dry-run` 을 먼저 돌려 POST/PATCH 갈림과 길이를 유저에게 보여준다.
- `push-text` 는 올린 뒤 재조회로 31개가 실제로 찼는지 대조한다. **lane 성공이 반영을 뜻하지 않는다**는 선례가 있다 (`docs/troubleshooting/2026-08-29-deliver-metadata-upload-silent-noop.md`).
- 심사 제출은 콘솔에서 유저가 한다.

## 6. 새 이벤트 추가

`fastlane/in_app_events/<새 event_id>/` 를 만들고 `event.json` 과 원고를 채우면 끝이다. **스크립트 코드를 고쳐야 하는 상황이 오면 파이프라인 설계 실패다** (지침 §4) — 고치지 말고 유저에게 보고한다.

## Red Flags — 이 생각이 들면 STOP

| 생각 | 실제 |
|---|---|
| "ko 승인 기다리는 동안 en 초안이라도 잡아두자" | ko 가 바뀌면 en 도 다시 쓴다 — 게이트가 순서인 이유는 재작업이 아니라 번짐이다 |
| "이미지에 이벤트 이름을 크게 넣자" | App Store 가 카드 하단 1/3 에 이름·설명을 겹쳐 그린다. 넣으면 겹친다 |
| "카드가 허전하니 로고라도 넣자" | 지침 §2-5 가 워터마크를 금지한다. 허전하면 `cardDeviceHeight` 를 키우거나 `scenes.card` 에 기기를 더 세운다 |
| "나머지 언어는 번역 대기 이슈로 미루자" | 그건 lproj 소관이다. ASC 메타데이터엔 미룰 자리가 없다 |
| "31개 이미지가 다 같으니 en 만 올리자" | 이미지 속 UI 가 언어별로 다르다. 언어 혼용은 지침 §5 위반 |
| "상한 2자 초과니까 조사만 빼자" | 문장이 깨지면 번역 29개가 같이 깨진다. 못 줄이겠으면 유저에게 되묻는다 |
| "명세에 있는 기능이니 없어도 그려 넣자" | 없는 기능 연출은 심사 리젝 사유다. 빼고 보고한다 |

## 종료 기록 — skill_end

업로드를 마쳤거나 자격증명이 없어 유저에게 인계하며 끝나는 시점에 `log-record.py skill_end` 를 1회 기록한다 (명령·compliance 규칙은 CLAUDE.md §1).
