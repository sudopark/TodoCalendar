---
issue: "#777"
subdomain: AIAgent
symptoms: [Attempt to present which is already presenting, 바텀시트 크래시, 키보드 입력 전송 크래시, AIAgentCommandViewController, AIAgentKeyboardInputViewController]
resolution: fixed
---

# 키보드 입력 시트에서 커맨드를 전송하면 present 충돌로 크래시

- **증상**: 키보드 입력 시트에서 전송 → `Attempt to present <AIAgentCommandViewController> on <MainViewController> ... which is already presenting <AIAgentKeyboardInputViewController>`. 음성 입력 경로는 무증상.

- **근본 원인**: `AIAgentOrchestrationUsecase.submit(_:)` 이 `.processing` 을 동기 방출하고 `state` 퍼블리셔에 `receive(on:)` 이 없어, `AIAgentKeyboardInputViewModelImple.send(_:)` 가 리턴하기 전에 `CalendarViewModel` sink → `routeToAICommand()` 까지 동기로 진행된다. 키보드 시트를 닫는 `closeScene()` 은 그 뒤라 present 가 항상 앞선다. 막았어야 할 `CalendarViewRouterImple.routeToAICommand()` 의 가드는 자기가 띄운 `presentedAICommandScene` 만 봤고, 키보드 시트는 `DayEventListRouter` 가 띄운 것이라 잡히지 않았다. 두 라우터가 같은 presenting VC 에 각자 present 하면서 서로의 상태를 모르는 구조가 원인.

- **해결**: `routeToAICommand()` 의 조건 분기를 `BaseRouterImple.dismissPresented(animated:_:)` 로 통일. `presentedViewController` 는 조상이 present 한 것도 반환하므로 소유 라우터와 무관하게 떠 있는 시트가 닫히고, 뜬 게 없으면 즉시 completion 이라 음성 경로는 동작이 동일하다. 추적 필드 `presentedAICommandScene` 제거.

- **기각 방향**:
  - `send()` 순서 뒤집기(closeScene 완료 콜백에서 submit) — keyboard→command 경로만 덮고 `routeToAICommand` 의 기존 분기는 그대로 남는다. 전송 실패 시 showError 를 띄울 scene 도 사라진다.
  - AI 시트 present 소유를 한 라우터로 일원화 — 근본적이나 CalendarScenes·AIAgentScene 배선을 넓게 뜯어야 해 이번 결함 대비 과대.

- **남은 구멍**: 커맨드 시트가 떠 있는 상태에서 `routeToAIKeyboardInput` 이 키보드 시트를 present 하는 반대 방향은 같은 구조적 구멍이나, 현 동선에선 커맨드 시트가 화면을 덮어 AI 진입 버튼에 닿을 수 없어 재현되지 않는다.
