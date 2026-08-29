---
issue: "#630"
subdomain: AIAgent
symptoms: [푸시 안옴, share extension, device_id, DailyLimitExceeded, ai job]
resolution: non-issue
---

# Share Extension으로 만든 AI job의 결과 푸시가 안 온다

- **증상**: 확장에서 공유 텍스트를 제출했는데 결과 푸시가 오지 않음. 확장이 `device_id` 헤더를 안 실어 보내는 것으로 의심됐다.
- **근본 원인**: 클라이언트 결함 아님. 테스트 시점에 일일 크레딧이 이미 소진돼 있었고, 서버가 한도 초과를 사전 감지하면 `jobService._createDailyLimitExceededJob`이 `status=FAILED`인 job으로 born 시킨다. 그러면 `agentLoopHandler.handle`의 `transitionToRunning` CAS가 false → `_sendFcm` 도달 전에 return. 한도 초과 job은 푸시가 발송되지 않는 경로다.
- **해결**: 서버 소관으로 이관 (TodoCalendar-Functions). 클라 변경 없음.

## device_id 전달은 정상 — 실측 근거

의심을 끊는 데 쓴 증거를 남긴다. 같은 의심이 재발하면 여기부터 본다.

- `AppExtensionBase.swift:97`이 `RemoteEnvironment.deviceId`를 채우고, `RemoteAPIImple.request`가 `defaultHeader()`를 항상 merge(충돌 시 default 우선)한다 — 확장·앱 모두 같은 경로.
- 앱(`ApplicationBase.swift:44-46`)과 확장(`AppExtensionBase.swift:17-19`) 둘 다 `UserDefaultEnvironmentStorageImple(suiteName: AppEnvironment.groupID)`를 쓴다. `install_id`가 App Group에 있어 같은 값이 나온다.
- Firestore `ai_jobs` 실측: 확장 경유 job(`commandText`가 `Interpret the shared text below…`로 시작)과 앱 경유 job의 `deviceId`가 동일.

## 조사 레시피

서버 로그·job 상태 확인 경로 (firebase CLI `functions:log`는 `-n` 페이징이 불안정해 신뢰하지 말 것):

```bash
gcloud logging read 'resource.labels.service_name="aiagentloop"' \
  --project todocalendar-1707723626269 --freshness=3d --limit 40 \
  --format='value(timestamp,severity,jsonPayload.message,jsonPayload.jobId)'

TOKEN=$(gcloud auth print-access-token)
curl -s -X POST "https://firestore.googleapis.com/v1/projects/todocalendar-1707723626269/databases/(default)/documents:runQuery" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"structuredQuery":{"from":[{"collectionId":"ai_jobs"}],"orderBy":[{"field":{"fieldPath":"expireAt"},"direction":"DESCENDING"}],"limit":8}}'
```

판독 기준: `AI usage` 로그가 있으면 agent loop가 실제로 돌았다는 뜻이고, 없으면 FAILED-born(사전 차단)이다. `_sendFcm`은 성공 시 로그를 남기지 않으므로 `device 없음`·`FCM 발송 실패` 경고가 없으면 발송된 것으로 읽는다.

- **기각 방향**: 확장에 제출 전 잔여 크레딧 확인 추가 — 확장은 fire-and-forget이 확정 스펙(#630 킥오프)이라 결과 통지 책임을 지지 않는다. 스펙을 결함으로 오판한 제안이었다.
