# App Store Connect 운영

ASC에 무언가를 올리는 작업의 **공통 앞단**(자격증명·실행환경·검증·제출)을 담는다.
무엇을 어떤 파일에 쓰는지는 대상별 정본이 따로 있다:

| 대상 | 정본 |
|---|---|
| 텍스트 메타데이터 (설명·키워드·subtitle·홍보문구) | [`fastlane/metadata/README.md`](../fastlane/metadata/README.md) |
| 스크린샷 | [`fastlane/screenshots.md`](../fastlane/screenshots.md) |
| 릴리즈 노트 (버전마다 갈림) | `release-notes` 스킬 |
| IAP 상품·심사 정보·데모 계정 | 이슈 #996 본문 |

---

## 1. 실행 환경 — `bundle` 이 시스템 ruby 로 잡힌다

PATH의 `bundle`은 `/usr/local/bin/bundle`(시스템 ruby 2.6)로 잡히는데 gem은 homebrew ruby(3.3)에
깔려 있다. 그대로 돌리면 `Bundler::GemNotFound`로 죽는다. 모든 fastlane 명령 앞에:

```sh
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
```

`Gemfile.lock`의 `BUNDLED WITH`가 homebrew bundler 버전인 것이 이 PATH가 정본이라는 근거다.

## 2. 자격증명 — ASC API 키

App Store Connect > 사용자 및 액세스 > 통합 > App Store Connect API 에서 발급.

- **권한은 App Manager 이상.** Developer 등급은 읽기만 되고 메타데이터 쓰기에서 403이 난다
- `.p8`은 생성 직후 **한 번만** 내려받을 수 있다. 놓치면 키를 새로 판다
- Issuer ID는 팀 단위라 키마다 다르지 않다
- IAP 서버 검증용 `APP_STORE_*` 키가 App Manager 등급이면 그대로 재사용한다

lane이 읽는 환경변수 셋. `ASC_KEY_CONTENT`는 **base64 한 줄**이다 (lane이 `is_key_content_base64: true`로 넘긴다):

```sh
export ASC_KEY_ID=...
export ASC_ISSUER_ID=...
export ASC_KEY_CONTENT=$(base64 -i AuthKey_<키ID>.p8)
```

`deliver init` 처럼 lane 밖에서 도는 명령은 이 env를 못 읽어 키 JSON을 따로 요구한다. 레포 밖에 두고 끝나면 지운다:

```sh
cat > /tmp/asc_api_key.json <<JSON
{"key_id":"$ASC_KEY_ID","issuer_id":"$ASC_ISSUER_ID","key":"$ASC_KEY_CONTENT","is_key_content_base64":true,"in_house":false}
JSON
```

## 3. lane 두 개 — 무엇도 심사에 제출하지 않는다

```sh
bundle exec fastlane ios upload_app_store_metadata      # 텍스트만
bundle exec fastlane ios upload_app_store_screenshots   # 스크린샷만
```

둘 다 `skip_binary_upload`·`submit_for_review: false`다. **심사 제출은 콘솔에서 직접 한다.**
바이너리(빌드)는 이 라인이 다루지 않는다.

- 메타데이터 lane은 `force: false`라 업로드 직전 HTML 프리뷰 확인 프롬프트가 뜬다 — **TTY에서 돌린다.**
  비대화형에서 돌리면 그 프롬프트에서 죽는다
- 스크린샷 lane은 186장 업로드가 시간 단위라 프롬프트 없이 돌고, 대신 진입 가드 3종이 사전 확인을 대신한다
- 두 lane 다 `precheck`의 `other_platforms` 룰과 무관하게 통과해야 한다 — 구글 캘린더 연동은 앱의 실제
  기능이라 competitor 언급이 아니다. 그래서 이 룰만 `warn`으로 낮췄고 나머지는 `error`다

## 4. 업로드 결과 검증 — lane 성공은 반영을 뜻하지 않는다

lane이 에러 없이 끝나도 실제로 아무것도 안 올라갈 수 있다
([사례](troubleshooting/2026-08-29-deliver-metadata-upload-silent-noop.md)). ASC 실상태를 직접 읽어 대조한다:

```ruby
# bundle exec ruby <파일>
require 'spaceship'
Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.from_json_file('/tmp/asc_api_key.json')
app = Spaceship::ConnectAPI::App.find('com.sudo.park.TodoCalendarApp')
v = app.get_edit_app_store_version(platform: 'IOS')
puts v.get_app_store_version_localizations.size      # 로케일 수
puts app.fetch_edit_app_info.get_app_info_localizations.size
```

보는 값은 두 갈래다 — `name`·`subtitle`·`privacy_url`은 **앱 정보** 로컬라이제이션,
`description`·`keywords`·`promotional_text`·`support_url`·`release_notes`는 **버전** 로컬라이제이션에 있다.

`fastlane/Preview.html`도 진단에 쓴다. deliver가 무엇을 읽었는지 그대로 담기므로, 로케일 섹션에 본문이
비어 있으면 파일을 못 읽은 것이다.

## 5. 순서 의존

1. **텍스트 메타데이터** — 로케일을 ASC에 새로 활성화하는 건 이 lane이다. 스크린샷 lane의 첫 가드가
   "스크린샷 로케일 집합 == 메타데이터 로케일 집합"이라 순서가 반대면 걸린다
2. **스크린샷**
3. **릴리즈 노트** — 활성화된 로케일 전부가 채워져야 제출이 열린다. 업데이트 버전에서 ASC 필수 필드고,
   lane은 중단이 아니라 경고로만 알린다 (첫 버전인지 판정이 로컬에서 안 되기 때문)
4. **빌드 업로드 → 콘솔에서 심사 제출**

## 6. 레포에 없는 것

- `fastlane/screenshots/` — 촬영·합성 산출물이라 gitignore. 다른 머신에서는 재생성부터 한다
- `fastlane/metadata/review_information/` — 데모 계정 아이디·비번, 담당자 이름·전화·이메일이 든다.
  **public 레포라 커밋 금지.** 파일이 없어도 업로드는 되고 ASC의 기존 심사 정보가 유지된다
- `fastlane/metadata/*/release_notes.txt` — 버전마다 갈려 `release-notes` 스킬이 만든다
