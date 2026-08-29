# App Store 메타데이터 (`deliver` 규약)

App Store Connect(ASC)에 올릴 텍스트 메타데이터를 fastlane `deliver` 규약대로 담아둔 곳이다.
`metadata/<ASC 로케일>/<필드>.txt` 구조이고, **파일명이 곧 ASC 필드**다.

## 업로드

```sh
export ASC_KEY_ID=... ASC_ISSUER_ID=...
export ASC_KEY_CONTENT=$(base64 -i AuthKey_<키ID>.p8)   # base64 한 줄
bundle exec fastlane ios upload_app_store_metadata
```

`deliver init` 기준선은 이미 레포에 있다 — 다시 돌릴 필요 없다. 업로드 직전 HTML 프리뷰 확인 프롬프트가
뜨므로 TTY 에서 돌린다.

`deliver` 는 **이 디렉토리에 있는 로케일을 ASC 에 새로 활성화한다.** 그래서 lane 은 올리기 전에 두 가지를
본다. `copyright.txt` 가 있는지(= 기준선 확보 여부), 그리고 모든 로케일이 ASC 심사 필수 필드
(`name`·`description`·`keywords`·`support_url`·`privacy_url`)를 갖췄는지. 하나라도 어긋나면 빠진 로케일
목록과 함께 중단한다. 파일이 없는 필드 자체는 `deliver` 가 건너뛰므로 ASC 값이 지워지지는 않는다.

`review_information/`(데모 계정·담당자 연락처)은 public 레포라 `.gitignore` 대상이다. 그 파일들이 없어도
업로드는 되고 ASC 의 기존 심사 정보가 유지된다. 심사 정보를 파일로 고치려면 그때만 `deliver init` 으로
내려받는다.

**lane 경로는 절대경로여야 한다** — `FastlaneCore::FastlaneFolder.path` 는 상대경로를 돌려주는데 fastlane 은
액션을 프로젝트 루트로 `chdir` 해서 실행한다. 상대경로로 두면 가드는 통과하고 업로드만 조용히 no-op 이 된다
([레코드](../../docs/troubleshooting/2026-08-29-deliver-metadata-upload-silent-noop.md)).

로케일을 새로 추가할 땐 `name`·`support_url`·`marketing_url`·`privacy_url` 을 en-US 값으로 채운다:

```sh
python3 scripts/propagate-appstore-metadata.py --apply   # --apply 없이 돌리면 계획만
```

스크린샷은 이 lane 이 건드리지 않는다. 촬영·합성·업로드 절차는 [`../screenshots.md`](../screenshots.md).

## 지금 들어 있는 것

31개 ASC 로케일 각각에 `subtitle.txt`·`description.txt`·`keywords.txt`·`promotional_text.txt`.

유저 승인이 끝난 최종 원고다. 문구를 임의로 다듬지 말 것.
다만 `promotional_text.txt` 는 31개 로케일 전부 버전 번호로 시작한다 — 그 표기만은 버전을 올릴 때
함께 갱신하고, 그건 `release-notes` 스킬 §0 소관이다.
길이 제한(문자 수 기준): subtitle 30, keywords 100, promotional_text 170, description 4000.

`release_notes.txt`(이번 버전의 새로운 기능, 상한 4000자)는 버전마다 갈리는 필드라 여기 없다 —
원고 작성·31개 로케일 현지화·업로드 절차는 `release-notes` 스킬 소관이고, 검사는
`python3 scripts/check-release-notes.py` 다.

## lproj ↔ ASC 로케일 매핑

앱의 lproj 코드와 ASC 로케일 코드는 대부분 같지만 6개가 다르다. 디렉토리명은 **ASC 코드**로 쓴다.

| lproj | ASC |
|---|---|
| `en` | `en-US` |
| `de` | `de-DE` |
| `es` | `es-ES` |
| `fr` | `fr-FR` |
| `nl` | `nl-NL` |
| `nb` | `no` |

나머지 25개는 lproj 코드와 같다:
`ko ja zh-Hans zh-Hant vi th it pt-BR ca sv da fi pl cs sk hu ru uk ro el hr tr id ms hi`
