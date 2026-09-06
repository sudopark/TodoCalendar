---
issue: "#1016"
subdomain: ExternalCalendar
symptoms: [구글 캘린더 연동 만료, 401 Invalid Credentials, 토큰 갱신 타임아웃, 백그라운드 진입 후 만료 다이얼로그, 재현 빌드가 수정 이전]
resolution: non-issue
---

# 구글 캘린더 만료 알림이 다시 떴는데, 재현 빌드가 수정 이전 버전이었다

- **증상**: 401 로 토큰 갱신이 돌고 갱신은 성공했는데 연동 만료 알림이 떴다. #1016 이 같은 증상으로 이미 수정된 뒤라 회귀로 의심됐다.
- **근본 원인**: 결함이 아니라 빌드 시점 문제. 재현 빌드는 Firebase 테스트 배포 `2.9.7(11)` — 빌드번호 11 은 `test_deploy.yml` 워크플로 run number 이고, run #11 은 2026-08-26 커밋 `b83d7c7d` 로 나갔다. #1016 수정 머지는 2026-08-28 이라 두 일 차이로 안 탔다. 해당 커밋의 `GoogleAPIAuthenticator.refresh` catch 는 에러 종류를 안 가리고 `removeCredential()` + `didRefreshFailed` 를 때리고, 판정 기준 `Error+ServerResponse.swift` 는 파일 자체가 없다.
- **해결**: 수정 없음. 최신 브랜치로 테스트 배포를 다시 떠서 확인한다. 수정은 develop(2026-08-28)·v3.0.0(2026-09-02 태그)에 포함.
- **기각 방향**: 조회 요청 타임아웃이 만료 처리를 유발한다 — Alamofire `AuthenticationInterceptor.retry` 가 `request.response` 없으면 첫 guard 에서 `.doNotRetry` 라 갱신 자체를 안 태운다. 만료 알림의 유일한 발화점은 `GoogleAPIAuthenticator.refresh` 의 catch 하나다.
- **기각 방향**: 같은 빌드에서 광고 배너가 안 보이는 것도 결함이다 — `AdExposureUsecaseImple.isBannerAdAllowed` 가 `isStarted && planId == .free` 이고 사용자가 유료 플랜이라 미노출이 정상 동작이다.

## 빌드번호로 배포 시점을 특정하는 법

테스트 배포 빌드번호는 `test_deploy.yml` 의 run number 다 (`Project+AppVersion.swift` 의 `buildNumber` 가 아니다 — 그쪽은 릴리즈 빌드용이라 테스트 배포 번호와 이력이 안 맞는다).

```bash
gh run list --workflow test_deploy.yml --limit 40 \
  --json number,createdAt,headBranch,headSha
git merge-base --is-ancestor <수정커밋> <headSha> && echo 포함 || echo 미포함
```
