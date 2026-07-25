# AIAgentScene Framework — CLAUDE.md

## 개요

AI 어시스턴트 진입 시트들. 키보드 입력 시트(AIAgentKeyboardInput)와 명령 처리 결과 시트(AIAgentCommand)로 구성. 진입점(마이크·AI 버튼)은 CalendarScenes 쪽이 소유하고, 이 프레임워크는 시트 Scene만 담당한다.

플랫 Scene 배치 (Scene 폴더화는 rules §3 — 새 Scene 추가하는 기회에 함께).

## Scene 상세

| Scene | 역할 | 비고 |
|---|---|---|
| `AIAgentKeyboardInput` | AI 지시 텍스트 입력 시트 | 전송/중지 아닌 닫힘은 `dismissByGesture`로 음성 입력 복귀 |
| `AIAgentCommand` | 명령 처리 상태 표시 | `AIAgentCommandState`(processing/confirm/done/failed) 스테이지별 뷰 분기, 헤더 타이틀이 상태 라벨 겸임 |

## 프레임워크 스코프 컴포넌트

| 컴포넌트 | 역할 |
|---|---|
| `Components/AIAgentUsageGaugeView` | 사용량/일일 한도 미니 게이지 (두 시트 공유, #713). `dailyLimit > 0`일 때만 렌더하는 건 호출측 책임 |

시트 헤더는 CommonPresentation `SheetHeaderView` 사용 (원래 이 프레임워크의 AIAgentSheetHeader였다가 #659에서 승격).
