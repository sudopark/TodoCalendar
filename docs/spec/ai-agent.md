# AI 에이전트 상세 스펙

자연어 지시를 서버가 해석해 이벤트를 만들고·고치고·지우는 경로. 클라이언트는 지시를 올리고 결과 job을 추적한 뒤, 데이터 변경이 실제로 있었을 때만 이벤트를 다시 당겨온다.

**로그인 필수** — 비로그인 상태에서는 진입 자체가 로그인 유도로 갈린다.

---

## 1. 세 가지 개념 — Command / Job / Mutation

| 개념 | 타입 | 의미 |
|---|---|---|
| Command | `ProcessingAICommand` | 클라이언트의 의도. jobId + confirm job 여부만 들고 로컬에 보관된다 |
| Job | `AIJob` | 서버의 실행 단위. `PENDING`·`RUNNING`·`DONE`·`CONFIRM`·`FAILED`·`REJECTED`·`CANCELED` |
| Mutation | `AIJobDataMutation` | job이 실제로 바꾼 데이터. `dataType`(todo/done/schedule/tag/event_detail) × `operation`(created/updated/deleted) |

셋을 "AI 요청" 하나로 뭉치면 안 된다. 하나의 command가 confirm을 거치면 job이 둘 생기고(원본 job → confirm job), mutation은 그중 어느 job에서든 나올 수 있다.

`AIJob.isFinish`는 `DONE`·`CONFIRM`·`FAILED`·`REJECTED`·`CANCELED`를 모두 종료로 본다. `CONFIRM`도 종료다 — 서버 입장에서 그 job은 끝났고 사용자 승인이 새 job을 만든다.

---

## 2. 상태 머신 (`AIAgentState`)

```
                    ┌──────────────────────────────┐
                    ▼                              │
  idle ──enterVoice/Keyboard/Image──▶ listening(method)
   ▲                                        │
   │                                     submit
   │                                        ▼
   │                                   processing(command)
   │                                        │
   │              ┌─────────────────────────┼─────────────────────┐
   │              ▼                         ▼                     ▼
   │      done(command,message)   confirm(command,message,     failed(command,
   │                               action,expireTime)           reason,errorCode)
   │              │                    │        │                     │
   └──────reset───┴────decline─────────┘   confirm()                  │
                                                │                     │
                                                └──▶ processing ──────┘
```

- `listening(AIAgentInputMethod)` — `.voice` / `.keyboard` / `.image`
- `confirm(...)`의 `expireTime`은 `confirmToken`(JWT)의 `exp` claim을 **서명 검증 없이** 파싱한 값이다. 만료 UI 판정 전용. `nil`이면 만료 시각 불명이라 카운트다운을 띄우지 않고 만료 검증도 건너뛴다.
- 만료 여부는 상태에 담지 않는다. 소비자가 `expireTime`을 현재 시각과 비교해 파생한다.

### 진입 가드

| 전이 | 허용 상태 |
|---|---|
| `enterVoiceInput()` | `idle`, `listening(.keyboard)`, `listening(.image)` |
| `enterKeyboardInput()` / `enterImageInput()` | `idle`, `listening(*)` |
| `submit(_:)` / `submitImageCommand(...)` | `idle`, `listening(*)` |

진입·제출 직전에 크레딧 소진을 한 번 더 확인하고, 소진이면 상태를 `failed(errorCode: .dailyLimitExceeded)`로 방출한다. 음성 경로가 `try?`로 submit 에러를 삼키기 때문에 throw가 아니라 상태 방출이다.

### 입력 길이 제한 (이미지 경로)

| 필드 | 상한 | 위반 시 |
|---|---|---|
| 인식 텍스트 | 10,000자 | `AIImageCommandSubmitFailReason.textTooLong` |
| 추가 지시문 | 1,000자 | `.instructionTooLong` |

빈 텍스트는 `.emptyText`, 처리 중 재제출은 `.busy`.

---

## 3. 입력 수단

| 수단 | 진입 | 처리 |
|---|---|---|
| 음성 | `enterVoiceInput()` | `SpeechRecognizeUsecase`가 인식 텍스트·음성 레벨을 스트리밍. 인식 종료 시 자동 submit |
| 키보드 | `enterKeyboardInput()` | 사용자가 직접 입력 후 submit |
| 이미지 | `enterImageInput()` | Vision OCR로 텍스트 추출 → `processInterpretCommand(inputSource: .imageOcr)` |

음성 인식 종료는 **텍스트 확보·무인식·실패를 가리지 않고** 바인딩을 접고 `idle`로 되돌린다. 바인딩이 남으면 다음 입력 세션에 이전 구독이 겹친다.

마이크 권한 알럿은 첫 `await`에서 바로 뜨기 때문에, 알림 권한 요청을 그보다 먼저 태워야 알림 알럿이 앞선다.

### `AICommandInputSource`

`text`(직접 입력) / `imageOcr`(이미지에서 뽑은 텍스트). 서버가 이 값으로 해석 지시문을 갈아끼운다.

---

## 4. 앱 밖 진입점

| 진입점 | 구현 | 동작 |
|---|---|---|
| Siri · 단축어 | `SendAICommandIntent` (`TodoCalendarAppShortcuts`) | 앱을 열지 않고 command 전송 (`openAppWhenRun = false`) |
| 액션 버튼 · 홈 화면 | `OpenAICommandInputIntent` | 입력 화면을 열고 진입 |
| 위젯 | `AICommandShortcutWidget` (`.accessoryCircular`, `.systemSmall`) | 원탭으로 입력 진입 |
| 제어 센터 | `AICommandControlWidget` (iOS 18+) | 한 스와이프로 입력 화면 |
| 공유 시트 | `TodoCalendarAppShare` 확장 | 공유된 텍스트·이미지를 command로 제출 |

이 경로들로 만들어진 job은 **앱 메모리에 없다.** 앱이 포그라운드로 올라올 때 `refreshProcessingJobIfNeeded()`가 로컬에 저장된 `ProcessingAICommand`를 읽어 추적을 이어받는다. 그래야 결과를 보여줄 수 있고, `canSubmit` 가드도 그 job을 인지해 덮어쓰기를 막는다.

---

## 5. Job 추적 — 폴링 + 푸시

`AICommandUsecaseImple.PollingPolicy` 기본값: **10초 간격, 총 10분 타임아웃**.

조회 트리거는 두 갈래를 merge 한다.

```
폴링 타이머 (10초) ──┐
                     ├──▶ GET /v1/ai/jobs/{id} ──▶ isFinish 면 스트림 종료
FCM 푸시 수신 ───────┘
```

FCM payload의 `jobId`가 `ApplicationRootViewModel` → `MainScene` → `handleJobStatusChanged(jobId)`로 흘러 즉시 재조회를 건다.

- 추적 중인 job과 id가 다르면 `idle`일 때만 로컬 기록에서 복원을 시도한다.
- **만료된 confirm job은 재조회하지 않는다.** 푸시가 와도 추적만 해제하고 끝낸다.

job 발급 시점에 `updateProcessingAICommand`로 로컬에 기록하고, 종료 시 `clearProcessingAICommand`로 지운다. 이 기록이 앱 재시작·확장 진입을 건너 job을 잇는 유일한 끈이다.

---

## 6. 확인(confirm) 플로우

무언가를 지우거나 바꾸는 작업은 서버가 `CONFIRM` 상태로 멈추고 `AIConfirmCommandAction`을 내려준다.

| 필드 | 의미 |
|---|---|
| `tool` | 실행 예정 도구 이름 |
| `args` | 도구 인자 (원본 `Data`) |
| `confirmToken` | 승인 토큰 (JWT). `exp`로 만료 판정 |
| `parentJobId` | 원본 job id |

- `confirm()` — 만료 시각이 과거면 **차단만 하고 상태 전이는 없다.** 유효하면 `processing`으로 올리고 `POST /v1/ai/command/confirm`.
- `decline()` — `POST /v1/ai/command/reject` 후 추적 해제, `idle`.
- `reset()` — 진행 중인 job이 있으면 `POST /v1/ai/command/cancel`, `idle`.

`REJECTED`·`CANCELED`로 끝난 job은 결과 메시지 없이 바로 `idle`로 접는다.

---

## 7. 이벤트 동기화 판정

job 결과의 mutation 중 **하나라도** `requiresEventSync`면 `EventSyncUsecase.sync()`를 건다.

| dataType | requiresEventSync |
|---|---|
| `todo` · `schedule` · `tag` | ✅ |
| `doneTodo` · `eventDetail` | ❌ |

mutation은 `done`·`confirm`·`failed`·`canceled` 어느 결과에도 실릴 수 있다 — 실패한 job도 일부는 반영했을 수 있으므로 결과 종류로 거르지 않는다.

---

## 8. 사용량과 한도

`GET /v1/ai/usage` 응답 하나가 사용량과 플랜을 같이 내려주지만, 플랜 정본은 `billingUserPlan` 키 하나다. 그래서 `AIAgentUsageLoadResult`가 둘을 흡수하지 않고 나란히 담는다.

```
AIAgentUsage
├── inputTokens / outputTokens
├── creditsUsed?          # 있으면 이 값이 사용량, 없으면 input+output
├── dailyLimit            # 플랜별 일일 한도
└── resetsAt              # UTC 자정 리셋
```

| 파생값 | 정의 |
|---|---|
| `usedCredits` | `creditsUsed ?? (inputTokens + outputTokens)` |
| `isLimitExceeded` | `dailyLimit > 0 && usedCredits >= dailyLimit` |
| `usedRatio` | `usedCredits / dailyLimit`, 0~1 클램프. 한도 0이면 0 |
| `isCreditExhausted(topupRemaining:)` | `isLimitExceeded && topupRemaining <= 0` |

- `usedRatio`가 1.0에서 클램프되기 때문에 초과 여부는 `isLimitExceeded`로 따로 본다.
- **일일 한도와 top-up 잔량은 합산하지 않는다.** `topupRemaining`은 이미 차감된 잔량이라 `usedCredits`에 더하면 초과분이 이중 반영된다.
- `topupRemaining`이 `nil`(플랜 정보 없음)이면 소진으로 보지 않는다.

한도 소진 상태에서 입력에 진입하거나 제출하면 paywall로 넘어간다 — `AIAgentCommandSceneListener.aiAgentCommandDidRequestPaywall()` → `CalendarViewRouter.routeToPaywall()`. 상세는 [billing.md](billing.md).

---

## 9. 알림 권한

job 결과는 푸시로 온다. 알림이 꺼져 있으면 앱을 다시 열기 전까지 결과를 모른다.

- `isNotificationPermissionDenied` 퍼블리셔가 입력 화면에 `AIAgentNotificationPermissionNoticeView`를 띄운다.
- 음성 입력 진입 시 마이크 알럿보다 **먼저** 알림 권한을 확인·요청한다.
- `refreshNotificationPermissionStatus()`로 설정 앱에서 돌아온 뒤 재판정한다.

---

## 10. API 엔드포인트

베이스: `{calendarAPIHost}/v1/ai`

| 메서드 | 경로 | 용도 |
|---|---|---|
| POST | `/command` | 자연어 command 제출 |
| POST | `/command/interpret` | 해석 전용 제출 (이미지 OCR 등, `inputSource` 동반) |
| POST | `/command/confirm` | 확인 승인 |
| POST | `/command/reject` | 확인 거부 |
| POST | `/command/cancel` | 진행 중 취소 |
| GET | `/jobs/{id}` | job 상태 조회 |
| GET | `/usage` | 사용량 + 현재 플랜 |

거부(reject)와 취소(cancel)는 둘 다 "실행 안 함"으로 끝나지만 유저 동선이 달라 별개 엔드포인트로 둔다.

시간 해석 기준은 요청마다 `CalendarSettingUsecase.currentTimeZone`의 IANA 문자열을 실어 보낸다.

---

## 11. 화면 (`AIAgentScene`)

| Scene | 역할 |
|---|---|
| `AIAgentCommand` | 진행 상태·결과·확인 요청을 보여주는 스테이지. 음성 입력의 기본 화면 |
| `AIAgentKeyboardInput` | 키보드 입력 시트 |
| `AIAgentImageCommand` | 이미지 선택 → OCR 결과 확인 → 추가 지시문 입력 |

공통 컴포넌트: `AIAgentUsageGaugeView`(잔여 크레딧 게이지), `AIAgentNotificationPermissionNoticeView`.

캘린더 화면은 `AIAgentState`를 구독해 command 단계에 들어가면 결과 시트를 자동으로 띄운다.

---

## 관련 파일

| 파일 | 역할 |
|---|---|
| `Domain/Sources/Models/AI/AICommand+Job.swift` | Command·Job·Mutation·ConfirmAction 모델 |
| `Domain/Sources/Models/AI/AIAgentState.swift` | 상태 머신 정의 |
| `Domain/Sources/Models/AI/AIAgentUsage.swift` | 사용량·한도 파생 |
| `Domain/Sources/Usecases/AI/AIAgentOrchestrationUsecase.swift` | 입력·상태 전이·동기화 판정 |
| `Domain/Sources/Usecases/AI/AICommandUsecase.swift` | job 발급·폴링·복원 |
| `Domain/Sources/Usecases/AI/AIAgentUsageUsecase.swift` | 사용량 갱신 |
| `Presentations/AIAgentScene/` | 입력·결과 화면 |
| `TodoCalendarApp/Sources/AppIntents/` | Siri·단축어·액션 버튼 진입 |
| `TodoCalendarApp/AppExtensions/Share/` | 공유 시트 진입 |
