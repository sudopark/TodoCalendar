# App Store 메타데이터 (`deliver` 규약)

App Store Connect(ASC)에 올릴 텍스트 메타데이터를 fastlane `deliver` 규약대로 담아둔 곳이다.
`metadata/<ASC 로케일>/<필드>.txt` 구조이고, **파일명이 곧 ASC 필드**다.

## ⚠️ 이 디렉토리를 지금 상태로 업로드하지 마라

`deliver`는 여기 있는 파일만 골라 올리지 않는다. **디렉토리 상태를 ASC에 그대로 반영한다.**
ASC에는 이미 이전 버전의 메타데이터(지원 URL·마케팅 URL·저작권·심사 정보 등)가 들어 있는데,
지금처럼 4개 필드만 든 디렉토리로 업로드하면 **파일이 없는 나머지 필드가 비워질 수 있다.**

**아직 `deliver init`을 돌리지 않았다.** 작업 당시 세션에 App Store Connect API 키가 없어서
현재 ASC 상태를 내려받지 못했고, 여기 있는 건 새로 쓴 en·ko 원고 4종뿐이다.

## 업로드 전에 반드시 이 순서로

1. `bundle exec fastlane deliver init` 으로 **현재 ASC 메타데이터를 통째로 내려받는다.**
   이게 기준선이다. 이 단계에서 `name.txt`·`release_notes.txt`·`privacy_url.txt`·
   `support_url.txt`·`copyright.txt`·`review_information/` 등이 실제 값으로 채워진다.
2. 내려받은 파일 위에 **아래 4개 필드만** 덮어쓴다 (git diff로 덮어쓴 범위 확인).
3. 그다음 업로드한다.

1번을 건너뛰고 2·3만 하면 ASC의 기존 필드가 날아간다.

## 지금 들어 있는 것

| 로케일 | 파일 |
|---|---|
| `en-US`, `ko` | `subtitle.txt`, `description.txt`, `keywords.txt`, `promotional_text.txt` |

유저 승인이 끝난 최종 원고다. 문구를 임의로 다듬지 말 것.
길이 제한(문자 수 기준): subtitle 30, keywords 100, promotional_text 170, description 4000.

업로드 lane(Fastfile) 배선은 별도 작업(B-3) 소관이다. 여기서 만들지 않았다.

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
