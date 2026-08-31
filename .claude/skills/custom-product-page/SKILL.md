---
name: custom-product-page
description: Use when building or updating App Store custom product pages (맞춤형 제품 페이지 / CPP) — 페이지별 스크린샷 라인업·프로모션 문구를 로케일별로 만들어 App Store Connect 에 올리는 절차. Triggers on "맞춤형 제품 페이지 만들어", "CPP 올려", "커스텀 프로덕트 페이지 현지화". Does NOT trigger on 앱 내 이벤트(in-app-event 스킬)·기본 스토어 페이지 스샷 교체(deliver)·가이드 이미지(localization rules §1).
---

# Custom Product Page — 맞춤형 제품 페이지 현지화·업로드

`deliver` 는 맞춤형 제품 페이지를 모른다. ASC API 를 직접 때리는 스크립트 셋을 순서대로 엮는 것이 이 스킬의 전부다.

**인앱 이벤트와 셋이 다르다** — 헷갈리면 산출물이 통째로 어긋난다:

| | in-app-event | custom-product-page |
|---|---|---|
| 이미지 안 캡션 | **금지** (App Store 가 얹는다) | **넣는 게 표준** |
| 규격 | 1920×1080 가로 + 1080×1920 세로 | 1320×2868 세로 × 6장 |
| 업로드 커밋 | `sourceFileChecksum` 넣으면 **거부** | `sourceFileChecksum` **필수** |

## 0. 준비 — 실행 환경과 자격증명

```sh
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
```

자격증명은 `secret/asc-api-key.json` 이 정본이고, 없으면 `ASC_KEY_ID`·`ASC_ISSUER_ID`·`ASC_KEY_CONTENT` 로도 된다. 발급 절차는 [`docs/appstore-connect-operations.md`](../../../docs/appstore-connect-operations.md) §1·§2.

**둘 다 없으면 여기서 멈추고 유저에게 인계한다** — 실행을 흉내내지 않는다.

## 1. 대상 확정

```sh
bundle exec ruby scripts/asc-custom-product-page.rb list
```

- 페이지 구성 정본은 `fastlane/custom_product_pages/pages.json` 이다. 페이지 id 는 사람이 읽는 슬러그이고 ASC 리소스 id 는 `ascPageId` 에 들어간다.
- **ASC 에 페이지가 없으면 `create` 가 만든다** — 인앱 이벤트와 달리 생성까지 스크립트가 덮는다. `ascPageId` 가 이미 찬 페이지는 건너뛰므로 재실행이 안전하다.
- 디렉토리 규약은 [`fastlane/custom_product_pages/README.md`](../../../fastlane/custom_product_pages/README.md).

## 2. 원고 — 승인 게이트 3개

**순서가 전부다.** 앞 게이트를 통과하기 전에 다음 것을 만들지 않는다.

### 2-1. ko 원고 (승인 게이트)

캡션(장면 수만큼)과 프로모션 문구(페이지 수만큼)의 한국어본을 유저에게 보여 승인받는다.

- 톤은 `fastlane/metadata/ko/description.txt` — 존댓말 평서문, 담백. 감탄·과장·이모지 없음.
- **화면 라벨은 ko lproj 값을 그대로 인용한다.** 자유번역 금지 — 페이지가 앱 기능을 다른 말로 부르면 독자가 그 화면을 못 찾는다. lproj 는 3곳이다 (`.claude/rules/localization.md` 서두).
  - 자주 틀리는 자리: 앱은 `할 일` 이 아니라 **`할일`**, `태그` 가 아니라 **`이벤트 종류`** 다.
- 유저가 준 명세 원고를 **옮겨 적지 말고 라벨 기준으로 워싱한다.** 명세가 앱에 없는 말을 쓰면 그것이 30배로 번진다.
- 프로모션 문구 상한 **170자**.

### 2-2. en 원문 (승인 게이트)

**여기가 급소다** — en 이 나머지 29개 언어의 번역 소스다 (#1015 가 그 사고였다).

- **화면 라벨은 en lproj 값 그대로.** ko 라벨을 영어로 옮기지 말고 en lproj 에서 찾아 쓴다.
- ko 를 직역하지 않는다 — `fastlane/metadata/en-US/description.txt` 의 어휘·리듬에 맞춘다. 캡션은 그 문서의 `■` 헤딩·본문 문장을 인용하면 대개 맞다.
- **도메인 3계층(Event ⊃ Todo / Schedule)을 en 에서 먼저 정확히 가른다.**

### 2-3. ko 이미지 한 세트 (승인 게이트) — 이 스킬 고유

`--locale ko` 로 촬영·합성해 **페이지 × 6장을 유저에게 보여 확인받는다.** 승인 전에 전 언어로 넘어가지 않는다.

31개 언어 촬영은 시간 단위다. 방향이 틀린 채로 돌리면 그 시간을 통째로 버린다.

### 2-4. 나머지 언어

- `captions.json` 은 **lproj 코드**, 프로모션 문구 디렉토리는 **ASC 코드**다. 6개가 다르고 매핑표는 `fastlane/metadata/README.md`.
- 번역 원칙은 `.claude/rules/localization.md` §2 — 도메인 3계층 용어 분리, 위젯 명칭 일관.
- **각 언어의 화면 라벨은 그 언어 lproj 값을 grep 해 인용한다.** en 라벨로 en lproj 를 grep 해 키를 얻고, 같은 키를 대상 언어 lproj 에서 읽는다.
- **번역 대기 트래킹 이슈 대상이 아니다.** 그건 lproj 소관이고 ASC 메타데이터엔 미룰 자리가 없다.
- 상한 초과는 `push-text --dry-run` 이 위반을 전량 모아 보여준다.

## 3. 이미지

**합성 규칙의 정본은 유저의 문서다:**
`/Users/sudo.park/Documents/sudo/인디앱 개발/To-do Calendar/CPP지침-맞춤형-제품-페이지-3종-명세.md`

레포에 복사본을 두지 않는다 — 가이드 레포와 같은 처리이고, 복사하면 짝이 어긋난다. **이미지 작업을 시작할 때 그 문서를 연다.**

### 3-1. 장면 정하기

장면 id → 화면 대응은 `scripts/cpp_scenes.py` 의 `SCENES` 다. 촬영 산출물은 `scripts/capture-appstore-screenshots.sh` 가 **기본 스토어 페이지와 함께 한 실행에** 뜬다.

명세가 지정한 장면이 카탈로그에 없으면 **카탈로그 스냅샷 케이스를 신설한다** (app-catalog 스킬 §1·§2 — 더미 텍스트는 하드코딩하지 말고 `CatalogStrings.strings` 나 프로덕션 경로로). 신설하면 셋을 함께 갱신한다:

- 카탈로그 케이스 (`<Framework>/Snapshots/<Name>CatalogSnapshots.swift`)
- `capture-appstore-screenshots.sh` 의 매핑 배열 — 화면은 `MAPPING`, 위젯 조각은 `WIDGET_MAPPING`, 시트 조각은 `SHEET_MAPPING`
- `cpp_scenes.SCENES`

**규격이 다른 조각은 반드시 하위 디렉토리로 뺀다** (`widgets/`·`sheets/`·`captions/cpp/`) — `verify_and_strip_alpha` 가 `$out/*.png` 를 전부 1320×2868 로 검사해 끊는다.

### 3-2. 촬영·합성

```sh
scripts/capture-appstore-screenshots.sh ko                       # 게이트 2-3
python3 scripts/compose-cpp-screenshots.py --locale ko
scripts/capture-appstore-screenshots.sh --all                    # 승인 후
python3 scripts/compose-cpp-screenshots.py --all-locales
```

- 촬영기는 **`iPhone 16 Pro Max - appstore_ref` 전용기**다. 카탈로그 기본기(iPhone 17)를 공유하면 규격이 1206×2622 로 나와 검사에서 끊긴다.
- 합성기는 규격·알파·장수·라인업 순서 이탈을 실패로 끊는다.
- 촬영 뒤 `git status --short -- '*__Snapshots__*'` 가 비어야 한다. 안 비면 `-only-testing` 이 안 먹어 검증 스냅샷이 재기록된 것이다.

### 3-3. 기계가 못 보는 자가 검증

`verify()` 는 해상도·알파·장수·순서만 본다. **나머지는 이미지를 열어서 확인한다** (명세 §7):

- [ ] **캡션 오탈자 없음 / 한 이미지 안 언어 혼용 없음** — 화면 안 더미 문자열까지 본다. 앱 lproj 가 아니라 `CatalogStrings.strings` 가 출처라 번역이 빠져 영어로 남기 쉽다
- [ ] **더미 데이터에 실명·실제 개인 일정·실존 회사명·실존 기관명 없음** (명세 §5)
- [ ] **각 페이지 첫 1~3장이 그 페이지 컨셉과 일치** (명세 §3 배치표)
- [ ] **4페이지 배경·서체 톤 통일** — 기본 스토어 페이지와도 같아야 한다
- [ ] **앱에 없는 기능을 연출하지 않았나** — 명세에 적혀 있어도 실제 빌드에 없으면 제외하고 유저에게 보고한다
- [ ] **MCP 연동·타사 앱 UI 가 안 나온다** (명세 §2)

## 4. 업로드

**텍스트가 먼저다** — 이미지는 로케일에 매달리므로 부모가 없으면 못 올린다.

```sh
bundle exec ruby scripts/asc-custom-product-page.rb create
bundle exec ruby scripts/asc-custom-product-page.rb push-text   --all-pages --all-locales --dry-run
bundle exec ruby scripts/asc-custom-product-page.rb push-text   --all-pages --all-locales
bundle exec ruby scripts/asc-custom-product-page.rb push-images --all-pages --all-locales --dry-run
bundle exec ruby scripts/asc-custom-product-page.rb push-images --all-pages --all-locales
```

- `--dry-run` 을 먼저 돌려 POST/PATCH 갈림과 길이를 유저에게 보여준다.
- 두 명령 다 올린 뒤 재조회로 대조한다. `push-images` 는 `assetDeliveryState.state == COMPLETE` 까지 본다 — **lane 성공이 반영을 뜻하지 않는다**는 선례가 있다 (`docs/troubleshooting/2026-08-29-deliver-metadata-upload-silent-noop.md`).
- 심사 제출과 Apple Ads 캠페인 연결은 콘솔에서 유저가 한다.

## 5. 새 페이지·새 로케일 추가

`pages.json` 에 항목을 더하고 원고를 채우면 끝이다. 로케일 추가는 `captions.json` 에 그 언어를 넣고 문구 파일을 만들면 코드 수정 없이 돈다.

**스크립트 코드를 고쳐야 하는 상황이 오면 파이프라인 설계 실패다** (명세 §4) — 고치지 말고 유저에게 보고한다. 단 **새 장면 추가는 예외**다 — 장면은 코드가 조립하므로 §3-1 의 셋을 함께 갱신한다.

## Red Flags — 이 생각이 들면 STOP

| 생각 | 실제 |
|---|---|
| "인앱 이벤트처럼 캡션은 빼자" | 스토어 스샷은 이미지 안 캡션이 표준이다 (명세 §4 서두). 빼면 빈 화면만 남는다 |
| "ko 확인 없이 31개 돌리자" | 촬영이 시간 단위다. 방향이 틀리면 그 시간을 통째로 버린다 |
| "31개가 다 같으니 en 만 올리자" | 이미지 속 UI 가 언어별로 다르다. 언어 혼용은 명세 §6 위반 |
| "명세 원고를 그대로 쓰자" | 명세가 앱 라벨과 다른 말을 쓰면(태그/이벤트 종류) 30배로 번진다. lproj 를 grep 해 확인한다 |
| "기본 스토어 페이지도 같이 바꾸자" | 심사 대기 중인 버전을 건드리게 된다. 별건이다 |
| "명세에 있는 장면이니 없어도 그려 넣자" | 없는 기능 연출은 심사 리젝 사유다. 빼고 보고한다 |
| "하단이 잘리니 목업을 줄이자" | 상단 인셋이 화면 아래를 버리는 것이 원인일 수 있다. 하단 고정 UI 가 있는 화면은 촬영 케이스가 safe area 를 직접 포함한다 |

## 종료 기록 — skill_end

업로드를 마쳤거나 자격증명이 없어 유저에게 인계하며 끝나는 시점에 `log-record.py skill_end` 를 1회 기록한다 (명령·compliance 규칙은 CLAUDE.md §1).
