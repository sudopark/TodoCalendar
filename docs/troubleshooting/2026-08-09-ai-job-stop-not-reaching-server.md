---
issue: "#795"
subdomain: AIAgent
symptoms: [중지 눌러도 취소 안됨, 중지 후 완료 푸시 도착, 포그라운드 복귀 시 진행중 안보임, 중지한 질의 결과 시트가 뒤늦게 노출]
resolution: fixed
---

# 중지를 눌러도 서버에 cancel이 안 나가고, 중지한 job의 결과가 뒤늦게 뜬다

- **증상**: 음성 커맨드 전송 직후 바텀시트에서 "중지"를 눌렀는데 (1) 잠시 뒤 처리 완료 푸시가 오고, (2) 포그라운드 복귀 시엔 진행 중 표시가 없다가, (3) 한참 뒤 중지했던 커맨드의 결과 시트가 튀어나온다.

- **근본 원인**: 두 개가 겹쳤다.
  - **취소 미발신** — `AIAgentOrchestrationUsecaseImple.reset()`이 `currentProcessingJobId`가 있을 때만 `cancelOngoingCommand`를 불렀다. 그 필드는 job 조회 응답이 처음 돌아올 때 채워지는데, `AICommandUsecaseImple.checkJob`은 `immediateCheck: false`라 첫 조회가 폴링 주기(10초) 뒤다. 그래서 시트가 뜬 직후 ~10초간 중지가 통째로 무시됐다. 서버 job은 계속 돌아 완료 푸시가 왔고(증상 1), 로컬 `ProcessingAICommand` 레코드도 `cancelOngoingCommand` 안에서만 지워지므로 남아 복원 대상이 됐다(증상 3).
  - **복귀 갱신 지연** — `ApplicationRootViewModelImple`이 `didBecomeActive`에 30초 `throttle`을 걸고 있었다. Combine의 `throttle`은 창에 갇힌 값을 **버리지 않고 창 끝에 흘린다**(실측: 5초 창에서 t=2s 입력이 t=5s에 방출). 그래서 백그라운드 복귀가 창 안에 들어가면 `refreshProcessingJobIfNeeded`가 최대 30초 늦게 돌았다 — 복귀 직후엔 아무것도 안 보이고(증상 2), 창 끝에 뒤늦게 복원이 돌아 결과 시트가 떴다(증상 3).

- **해결**:
  - 커맨드 처리 진행 상태를 `AICommandProcessing`(`.started(jobId:)` / `.job(AIJob)`)으로 모델링하고, `processCommand`·`processConfirmCommand`·`restoreCommandifNeed`의 방출 타입을 여기로 통일했다. 생성 API 응답의 jobId가 `.started`로 먼저 나가므로 첫 조회를 기다릴 이유가 없다.
  - `AIAgentOrchestrationUsecaseImple`이 그 초기 이벤트로 `currentProcessingJobId`를 채운다 — 진행 중 job의 소유는 원래대로 orchestration 한 곳이고, 별도 추적 상태를 만들지 않았다.
  - `handleJobResult`가 종료(confirm 제외)·실패 completion에서 `currentProcessingJobId`를 비운다. 정상 완료 후 확인(acknowledge)에도 끝난 job에 cancel API가 나가던 문제가 여기서 함께 해소됐다.
  - `didBecomeActive`의 throttle 제거. 진행 중 job이 없으면 이어받기가 로컬 조회로 끝나 잦은 호출의 비용이 낮다.

- **남은 구멍**: 생성 API 응답이 오기 전(POST in-flight, 1~3초)에 누른 중지는 여전히 나가지 않는다. 구독이 끊기며 생성 Task가 취소돼 jobId를 못 받기 때문. 막으려면 생성을 구독 수명에서 분리해야 하는데 창이 짧아 이번엔 두지 않았다.

- **기각 방향**: `throttle`의 `latest: true` 전환 — Combine에서 `latest`는 trailing 방출 여부가 아니라 갇힌 값 중 무엇을 낼지만 고르고, 이 시나리오는 갇힌 값이 하나라 동작이 동일하다 (실측 확인).
- **기각 방향**: leading-only 상한(창 안 이벤트 폐기) — 정상 복귀가 통째로 버려져 증상이 "늦게 뜸"에서 "안 뜸"으로 바뀔 뿐이다.
- **기각 방향**: 생성된 jobId를 가짜 `AIJob`(status pending)으로 스트림에 선방출 — 타입이 그대로라 소비자가 "조회된 job"과 구분할 수 없고, 방출 시퀀스를 검증하던 기존 테스트 10여 개가 함께 밀렸다. 별도 case로 모델링해야 구분이 타입에 드러난다.
- **기각 방향**: `AICommandUsecaseImple`이 jobId를 자체 보관 + `cancelOngoingCommand()` 무인자화 — 진행 중 job 소유가 orchestration과 usecase 두 곳으로 갈라진다.
- **기각 방향**: 취소 예약 상태기계(`none/creating/ongoing`) + 생성 Task 분리 — 응답에 이미 있는 jobId를 두고 별도 추적 상태를 신설하는 과설계.

## 참고 — 기존 플레이키

`AICommandUsecaseImpleTests`의 "실패/타임아웃 직후 `loadProcessingAICommand() == nil`"류 케이스는 `clearProcessingAICommand`가 fire-and-forget `Task`인데 테스트가 대기 없이 읽어 랜덤 실패한다. develop에서도 동일하게 재현되는 기존 문제라 이번 변경의 회귀가 아니다.
