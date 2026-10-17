---
issue: "#1115"
subdomain: Event
symptoms: [AI 커맨드 결과 이벤트가 안보임, 포그라운드 복귀 후 이벤트 누락, 성공 버텀시트는 뜨는데 이벤트 없음, syncEnd 안옴, 이벤트 싱크 도는데 화면 반영 안됨]
resolution: fixed
---

# 취소된 event sync 가 완료를 보고해, 뒤이어 시작된 sync 의 종료 신호가 사라진다

- **증상**: 앱 밖(위젯·인텐트·공유 시트)에서 보낸 AI 커맨드가 완료돼 푸시가 오고, 포그라운드 복귀로 앱에 들어오면 성공 버텀시트는 정상인데 매칭되는 이벤트가 종종 안 보인다. 다른 기기에서 이벤트를 고친 뒤 포그라운드 복귀하는 경로는 멀쩡하고, AI job 결과가 있을 때만 재현된다.

- **근본 원인**: `EventSyncUsecaseImple.runSyncTask()` 가 취소를 관측하지 않고 끝까지 돌아 `syncStatus.send(.idle)` 과 completion 통지를 냈다. dataType 루프의 `catch` 가 `CancellationError` 를 로그로 삼켜 취소가 밖으로 새 나가지 않는다.

  AI job 결과가 있는 포그라운드 복귀에서는 `sync()` 가 최대 3번 겹쳐 뜬다 — `CalendarViewModel` 의 willEnterForeground, `MainViewModel.refreshProcessingJobIfNeeded` → restore → `AIAgentOrchestrationUsecase.triggerEventSyncIfNeeded`, 푸시 탭 → `handleJobStatusChanged` → 같은 경로. `sync()` 는 첫 줄이 `cancelSync()` 라 앞 task 를 취소하는데, 취소된 task 가 뒤늦게 끝나며 유령 `.idle` 을 흘린다. 그게 다음 task 의 `.incrementalSyncing` 과 진짜 `.idle` 사이에 끼면 `syncStatus` 의 `removeDuplicates()` 가 진짜 완료를 중복으로 보고 삼킨다. `syncEnd` 가 안 오니 `CalendarViewModel.refreshEvents` 가 안 돌고, 이벤트는 로컬 DB 에만 있고 `SharedDataStore` 에는 안 올라와 화면에서 빠진다.

  일반 포그라운드 복귀는 `sync()` 가 한 번뿐이라 겹칠 앞 task 가 없다 — 증상이 AI job 결과에만 붙는 이유다.

- **해결**: `runSyncTask()` 의 마지막 `send(.idle)` 앞에 `try Task.checkCancellation()`. 취소된 task 는 상태도 안 바꾸고 completion 도 안 낸다. 부수 효과로 `BackgroundEventSyncUsecaseImple` 의 BGTask 경로도 바로잡힌다 — 기존엔 `expirationHandler` 가 `cancelSync()` + `scheduleTask()` 를 한 뒤, 늦게 끝난 취소 task 가 `setTaskCompleted(success: true)` 와 `scheduleTask()` 를 한 번 더 불렀다.

- **기각 방향**: `guard !Task.isCancelled else { return }` — 정상 반환이라 `sync(_:)` 의 `completed?()` 가 그대로 돌아, BGTask 를 성공으로 보고하는 쪽을 못 막는다.
