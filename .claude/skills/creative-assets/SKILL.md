---
name: creative-assets
description: Use when making or updating App Store creative assets — 제품 페이지 헤더(21:9)·검색 결과(3:2) 가로 이미지를 로케일별로 합성해 Asset Library 에 올리고 앱 버전 로케일에 placement 로 거는 절차. Triggers on "크리에이티브 에셋 올려", "헤더 이미지 만들어", "검색 결과 이미지 교체". Does NOT trigger on 기본 스토어 스크린샷(deliver)·맞춤형 제품 페이지(custom-product-page 스킬)·앱 내 이벤트(in-app-event 스킬).
---

# Creative Assets — 헤더·검색 결과 이미지 현지화·업로드

`deliver` 는 Asset Library 를 모른다. 촬영 → 합성 → ASC API 스크립트를 순서대로 엮는 것이 이 스킬의 전부다.
fastlane/fastlane#30442 가 릴리스되면 lane 으로 옮길지 다시 판단한다.

**CPP·인앱 이벤트와 넷이 다르다** — 헷갈리면 업로드가 통째로 거부된다:

| | custom-product-page | in-app-event | creative-assets |
|---|---|---|---|
| 규격 | 1320×2868 세로 × 6장 | 1920×1080 + 1080×1920 | 헤더 3840×1646 + 검색 결과 3:2 (합성은 3840×2560). 둘 다 PNG·알파 없음 |
| 업로드 커밋 | `sourceFileChecksum` 필수 | 체크섬 넣으면 거부 | `uploaded: true` 만 (체크섬 없음) |
| 매달리는 곳 | 페이지 로케일 | 이벤트 로케일 | **편집 가능한 앱 버전** 로케일 — 심사 제출 뒤엔 409 |
| 교체 | 스크린샷 지우고 다시 올림 | 같음 | placement 는 수정 불가 — **지우고 새로 만든다** |

## 0. 준비 — 실행 환경과 자격증명

```sh
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
```

자격증명은 `secret/asc-api-key.json` 이 정본이고, 없으면 `ASC_KEY_ID`·`ASC_ISSUER_ID`·`ASC_KEY_CONTENT` 로도 된다. 발급 절차는 [`docs/appstore-connect-operations.md`](../../../docs/appstore-connect-operations.md) §1·§2.

**둘 다 없으면 여기서 멈추고 유저에게 인계한다** — 실행을 흉내내지 않는다.

## 1. 대상 확정

```sh
bundle exec ruby scripts/asc-creative-assets.rb list
```

- 대상은 `PREPARE_FOR_SUBMISSION` 인 iOS 버전이다. 둘 이상이거나 없으면 스크립트가 멈추고, 그때는 유저에게 버전을 물어 `--version` 으로 준다.
- 이미 심사에 들어간 버전은 못 바꾼다. 다음 버전이 생길 때까지 기다린다.
- 원고·배치 구성 자리는 [`fastlane/creative_assets/README.md`](../../../fastlane/creative_assets/README.md) 다. 배치는 `header`·`search` 둘로 고정이다.

## 2. 원고 — 승인 게이트 3개

**순서가 전부다.** 앞 게이트를 통과하기 전에 다음 것을 만들지 않는다.

톤·화면 라벨·en 원문 규칙은 custom-product-page 스킬 §2-1·§2-2 를 그대로 따른다. 여기서 다른 것만 적는다.

### 2-1. ko 원고 (승인 게이트)

헤더·검색 결과 캡션 두 줄의 한국어본을 유저에게 보여 승인받는다.

- 헤더는 각 언어 `fastlane/metadata/<ASC로케일>/description.txt` 첫 줄(마침표 뺌)을 쓰면 31개 언어가 이미 현지화돼 있다. 그 언어 첫 줄이 en 첫 줄과 뜻이 다르면 그 언어만 en 헤더를 번역해 쓰고, 유저에게 목록을 보고한다.

### 2-2. en 원문 (승인 게이트)

헤더·검색 결과 캡션 두 줄의 en 원문을 승인받는다. 29개 언어가 이 원문으로 번역된다.

### 2-3. ko 이미지 한 세트 (승인 게이트)

`ko` 하나로 촬영·합성해 두 장을 유저에게 보여 확인받는다. 31개 언어 촬영은 시간 단위다.

### 2-4. 나머지 언어

- `captions.json` 은 **lproj 코드**, 산출 디렉토리는 **ASC 코드**다. 6개가 다르고 매핑표는 `fastlane/metadata/README.md`.
- 번역 원칙은 `.claude/rules/localization.md` §2 — 도메인 3계층 용어 분리, 위젯 명칭 일관. 위젯 용어는 기존 스토어 캡션(`Presentations/CommonPresentation/Snapshots/AppStoreCaptionSnapshots.swift` 의 `widgetStyle` 원고)과 맞춘다.
- 번역 대기 트래킹 이슈 대상이 아니다. ASC 메타데이터엔 미룰 자리가 없다.

## 3. 이미지

### 3-1. 장면

장면 id → 화면 대응은 `scripts/cpp_scenes.py` 의 `SCENES` 다. 배치당 1~3개를 `assets.json` 순서대로 가로로 놓는다. 기기 한 대에 안 들어가는 장면(C10 테마 계단)은 쓸 수 없다.

### 3-2. 촬영·합성

```sh
scripts/capture-appstore-screenshots.sh ko                       # 게이트 2-3
python3 scripts/compose-creative-assets.py --locale ko
scripts/capture-appstore-screenshots.sh --all                    # 승인 후
python3 scripts/compose-creative-assets.py --all-locales
```

- **촬영 한 번에 원고 두 벌이 다 있어야 한다** — `fastlane/custom_product_pages/captions.json` 과 `fastlane/creative_assets/captions.json`. 촬영 스크립트가 기본 스토어·CPP·크리에이티브 캡션을 한 실행에 뜨고, 어느 쪽이든 그 언어 캡션이 없으면 그 언어 전체를 실패로 끊는다. 둘 다 gitignore 대상이라 워크트리마다 따로 있다 — 없으면 어느 워크트리의 원고를 가져올지 유저에게 묻고, 복사도 유저에게 맡긴다 (다른 워크트리 파일이라 권한 검사에서 막힌다).
- 촬영기는 `iPhone 16 Pro Max - appstore_ref` 전용기다.
- 합성기는 규격·알파·PNG·두 파일 존재를 실패로 끊는다. 업로드 스크립트가 같은 가드를 인증 전에 한 번 더 본다.

### 3-3. 기계가 못 보는 자가 검증

- [ ] 캡션 오탈자 없음 / 한 이미지 안 언어 혼용 없음
- [ ] 캡션이 지나치게 작아지거나 기기와 겹치지 않음 — `fastlane/creative_assets/images/*/header.png` 의 왼쪽 캡션 칸(x 0~1700)과 `search.png` 의 위쪽 캡션 칸(y 0~700)을 잘라 31개 언어를 한 장에 모아 훑는다
- [ ] 더미 데이터에 실명·실존 회사명 없음
- [ ] 앱에 없는 기능을 연출하지 않음

## 4. 업로드

```sh
bundle exec ruby scripts/asc-creative-assets.rb push --all-locales --dry-run
bundle exec ruby scripts/asc-creative-assets.rb push --all-locales
```

- `--dry-run` 을 먼저 돌려 로케일별 신규·교체와 파일 크기를 유저에게 보여주고 승인받는다.
- 스크립트는 이미지 처리 완료(`PREPARE_FOR_SUBMISSION`)와 specId 를 확인한 뒤에만 기존 placement 를 지운다. 그 전 단계에서 실패하면 이전 이미지가 남고, 지운 뒤 생성에서 실패하면 그 자리가 빈다. 어느 쪽이든 실패 목록만 `--locale` 로 다시 돌리면 채워진다.
- 끝나면 재조회 표에서 ✓ 를 확인한다. 교체로 빠진 이전 이미지는 지우지 않는다.
- 심사 제출은 콘솔에서 유저가 한다.

## Red Flags — 이 생각이 들면 STOP

| 생각 | 실제 |
|---|---|
| "CPP 처럼 체크섬을 싣자" | Asset Library 커밋은 `uploaded: true` 만 받는다 |
| "16:9 공용 에셋 하나로 두 자리를 다 채우자" | 5244×2950 고정 규격이라 합성 기하가 따로 필요하다. 지금 파이프라인 범위 밖이다 |
| "심사 중인 버전에 바로 걸자" | 편집 불가 버전은 409 다. 다음 버전을 기다린다 |
| "ko 확인 없이 31개 돌리자" | 촬영이 시간 단위다. 방향이 틀리면 그 시간을 통째로 버린다 |
| "기존 placement 를 먼저 지우고 올리자" | 업로드가 실패하면 그 로케일이 빈 채로 남는다. 스크립트 순서를 바꾸지 않는다 |

## 종료 기록 — skill_end

업로드를 마쳤거나 자격증명이 없어 유저에게 인계하며 끝나는 시점에 `log-record.py skill_end` 를 1회 기록한다 (명령·compliance 규칙은 CLAUDE.md §1).
