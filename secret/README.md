# secret/

레포에 커밋하지 않는 자격증명 자리다. `secret/` 전체가 gitignore 대상이고 이 README 만 예외다.

## `asc-api-key.json` — App Store Connect API 키

`scripts/asc-in-app-event.rb` 가 자격증명을 못 찾으면 이 파일을 읽는다. `.p8` 은 base64 로 바꿀
필요 없이 **파일 경로만** 적는다 (spaceship 의 `Token.create` 가 `filepath:` 로 직접 읽는다).

```json
{
  "key_id": "XXXXXXXXXX",
  "issuer_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "key_filepath": "/절대/경로/AuthKey_XXXXXXXXXX.p8"
}
```

- `key_id`·`issuer_id` 는 ASC → 사용자 및 액세스 → 통합 → App Store Connect API 에서 나온다.
- **권한은 App Manager 이상.** Developer 등급은 읽기만 되고 쓰기에서 403 이 난다.
- `.p8` 은 발급 직후 한 번만 내려받을 수 있다. 레포 밖에 두고 경로만 여기 적는다.

발급·권한 상세는 [`docs/appstore-connect-operations.md`](../docs/appstore-connect-operations.md) §2.

## 환경변수가 우선한다

`ASC_KEY_ID`·`ASC_ISSUER_ID`·`ASC_KEY_CONTENT` 가 셋 다 차 있으면 그쪽을 쓴다. CI 처럼 파일을 둘 수
없는 자리를 위한 경로다.

fastlane lane(`upload_app_store_metadata` 등)은 아직 env 만 읽는다. 이 파일로 lane 을 돌리려면:

```sh
export ASC_KEY_ID=$(python3 -c "import json;print(json.load(open('secret/asc-api-key.json'))['key_id'])")
export ASC_ISSUER_ID=$(python3 -c "import json;print(json.load(open('secret/asc-api-key.json'))['issuer_id'])")
export ASC_KEY_CONTENT=$(base64 -i "$(python3 -c "import json;print(json.load(open('secret/asc-api-key.json'))['key_filepath'])")")
```
