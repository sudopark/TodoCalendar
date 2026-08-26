# App Store 메타데이터 (`deliver` 규약)

App Store Connect(ASC)에 올릴 텍스트 메타데이터를 fastlane `deliver` 규약대로 담아둔 곳이다.
`metadata/<ASC 로케일>/<필드>.txt` 구조이고, **파일명이 곧 ASC 필드**다.

## ⚠️ 이 디렉토리를 지금 상태로 업로드하지 마라

`deliver`는 **디렉토리에 있는 로케일을 ASC에 새로 활성화한다.** 지금은 4개 필드뿐이라
그대로 올리면 31개 로케일이 `name`·`support_url`·`release_notes`가 빈 채로 생긴다.
ASC 심사 제출에 필수인 필드라 제출이 막히고, 31개 로케일을 콘솔에서 손으로 채워야 한다.
(파일이 없는 필드 자체는 `deliver`가 건너뛰므로 ASC 값이 지워지지는 않는다.)

**아직 `deliver init`을 돌리지 않았다.** 작업 당시 세션에 App Store Connect API 키가 없어서
현재 ASC 상태를 내려받지 못했고, 여기 있는 건 새로 쓴 원고 4종뿐이다.

`upload_app_store_metadata` lane은 `deliver init`이 항상 만드는 `copyright.txt`가 이 디렉토리에
있는지로 기준선 확보 여부를 판정하고, 없으면 업로드 전에 중단한다.

## 업로드 전에 반드시 이 순서로

```sh
# 1. ASC API 키 JSON (레포 밖에 두고 끝나면 지운다). ASC_* 값은 upload lane과 같은 것
cat > /tmp/asc_api_key.json <<JSON
{"key_id":"$ASC_KEY_ID","issuer_id":"$ASC_ISSUER_ID","key":"$ASC_KEY_CONTENT","is_key_content_base64":true,"in_house":false}
JSON

# 2. 현재 ASC 메타데이터를 통째로 내려받아 기준선을 만든다
#    name·release_notes·privacy_url·support_url·copyright·review_information/ 이 실제 값으로 채워진다
#    스크린샷은 sub-work C 소관이라 건너뛴다
DELIVER_SKIP_SCREENSHOTS=true bundle exec fastlane deliver init --api_key_path /tmp/asc_api_key.json

# 3. init이 덮어쓴 우리 원고를 되돌린다 (init이 건드리는 건 ASC에 이미 있는 로케일의 파일뿐이라
#    수정된 tracked 파일 = 우리 4필드)
git checkout -- $(git diff --name-only -- fastlane/metadata)

# 4. init이 못 만든 신규 로케일의 name·support_url·privacy_url을 채운다 (ASC에 없던 로케일이라 빈 채로 남는다)

# 5. 업로드 (업로드 뒤 precheck가 자동으로 돈다)
bundle exec fastlane ios upload_app_store_metadata
```

## 지금 들어 있는 것

31개 ASC 로케일 각각에 `subtitle.txt`·`description.txt`·`keywords.txt`·`promotional_text.txt`.

유저 승인이 끝난 최종 원고다. 문구를 임의로 다듬지 말 것.
길이 제한(문자 수 기준): subtitle 30, keywords 100, promotional_text 170, description 4000.

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
