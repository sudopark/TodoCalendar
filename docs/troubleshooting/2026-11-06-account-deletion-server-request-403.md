---
issue: "#1359"
subdomain: Account
symptoms: [계정 삭제 안 됨, 계정 삭제 실패, 탈퇴 안 됨, DELETE /v2/accounts/account 403, NoAccessToken, account_deletion_requests 0건, 서버 데이터 남음, 퍼지 대상 누락]
resolution: fixed
---

# 계정 삭제 시 서버 삭제 요청이 항상 403 으로 실패한다

- **증상**: 유저가 앱에서 계정을 삭제하지 못한다고 문의했다 (앱 3.1.1, iOS 26.7.2). 로그가 남은 10/07 이후 `DELETE /v2/accounts/account` 45건이 전부 403 이고, `account_deletion_requests` 는 0건이다. 403 은 인증 전에 나서 uid 가 안 남으므로 영향 유저 수는 모른다.

- **근본 원인**: 출시본 v3.1.1·v3.1.2 의 `CalendarAPIAutenticator.shouldAdapt` 에서 `AccountAPIEndpoints.account` 가 `default: false` 로 빠져 Bearer 토큰이 안 붙는다. develop 도 `AccountAPIEndpoints.authorization` 의 `.account` 가 `.none` 이고, `AccountEndpointsTests` 기대표도 `.none` 이라 테스트가 못 잡는다. 서버 `validateToken` 이 토큰 없는 요청을 403 `NoAccessToken` 으로 막고, `AuthRepositoryImple.deleteAccount` 가 이 실패를 `try?` 로 삼켜 유저에게 안 보인다.

- **영향**: 앱 삭제를 끝낸 유저는 Firebase 계정만 지워지고 서버 데이터가 남는다. 삭제 요청 레코드가 없어 퍼지 대상에서도 빠진다.

- **해결**: 3.1.3 에서 `CalendarAPIAutenticator.shouldAdapt` 가 `AccountAPIEndpoints` 를 case 마다 판정해 `.account` 에 토큰을 붙인다 (#1359). develop 은 master 를 당길 때 `AccountAPIEndpoints.authorization` 의 `.account` 와 `AccountEndpointsTests` 기대표를 `.calendarAPI` 로 바꿔야 한다.

- **수동 삭제 시 주의**: `purge_account.js` 만으로 끝나지 않는다. `account_infos` 가 남아 있으면 `purgeUser` 가 현역 계정으로 보고 중단하고, Firebase Auth 계정은 지우지 않는다.

- **기각 방향**: 삭제 요청 레코드가 없으니 유저가 확인 단계까지 못 갔다고 보는 것 — 레코드가 없는 이유는 403 이다.
