---
name: cs-reply
description: Use when replying by email to a customer inquiry that arrived in Slack #todocalendar_cs — CS 답장 메일의 제목·본문 작성, Gmail 발송, Slack 처리 표시 시점. Triggers on "답장 보내자", "이 문의 답변 메일 써", "CS 답변해줘", "메일 보내줘", CS 건을 분류한 뒤 고객에게 회신할 차례가 됐을 때. Does NOT trigger on 문의의 원인 규명(troubleshoot 스킬), 기능 요청 이슈 생성(issue 스킬), 스토어 문구·릴리즈 노트(release-notes 스킬), Slack 채널 읽기만 하는 보고.
---

# CS Reply — 문의 답장 메일

**고객에게 나가는 메일은 서비스명이 박힌 제목과 고정된 본문 순서를 가진다. 유저는 한국어 전문 번역을 보고 승인하며, 승인 전엔 발송하지 않는다.**

## 입력

Slack `#todocalendar_cs` (`C07H0U8EVPU`) 에 `incoming-cs` 봇이 올린 메시지 한 건이 단위다. 수신자 주소는 `incomming cs from:` 줄에 있고, 환경(user id · os version · app version · device model)이 아래 줄에 붙는다. 문의는 Gmail 로 들어오지 않으므로 답장은 **새 메일**이다 — `replyToMessageId` 를 쓸 원 메일이 없다.

## 절차

1. **착수 표시** — 그 Slack 메시지에 `eyes` 리액션 (`slack_add_reaction`).
2. **분류** — 결함이면 troubleshoot 스킬로 원인부터, 기능 요청이면 issue 스킬로 이슈를 먼저 딴다. 사용법 문의는 `docs/spec/*` 와 그 로케일 `Localizable.strings` 로 실제 동작·라벨을 확인한다. 답장은 사실이 확정된 뒤 쓴다.
3. **초안 제시** — 유저에게 제목·본문(고객 언어)·**한국어 전문 번역**을 함께 보인다. 번역이 빠진 초안은 승인 대상이 아니다 — 유저는 번역을 읽고 결정한다.
4. **발송** — 유저가 승인하면 Gmail `send_message` (발신 `todocalendar.help@gmail.com`, `to` = 문의 주소, `body` 는 plain text). 승인 전엔 `create_draft` 까지만 허용된다. 승인 뒤 초안을 고쳤으면 고친 본과 번역을 다시 보이고 승인을 다시 받는다.
5. **완료 표시** — 발송 결과의 message id 를 받은 뒤 같은 Slack 메시지에 `white_check_mark` 리액션.

## 제목

서비스명은 App Store 등재명 `To-do Calendar` 하나다 (`fastlane/metadata/*/name.txt`). `TodoCalendar`·`Todo Calendar` 는 쓰지 않는다. 원 메일이 없으니 `Re:` 를 붙이지 않는다.

| 언어 | 제목 |
|---|---|
| ja | `[To-do Calendar] <주제>に関するお問い合わせへの回答` |
| en | `[To-do Calendar] Reply to your inquiry about <topic>` |
| ko | `[To-do Calendar] <주제> 문의에 대한 답변` |
| 그 외 | 같은 모양을 그 언어로 — 서비스명 + 주제 + "문의에 대한 답변" |

`<주제>` 는 문의를 한 구절로 — `六輝の表示` · `widget holiday display` · `계정 삭제`.

## 본문 — 순서 고정

고객이 쓴 언어로 쓴다. 여섯 요소를 이 순서로 채운다.

1. **호칭** — 문의 본문에서 이름을 알 수 있을 때만 (`佐々木様` · `Hi Allison,`). 메일 주소의 `@` 앞부분은 이름이 아니다. 모르면 이 줄을 통째로 뺀다.
2. **신원·감사** — `To-do Calendar サポートです。お問い合わせいただきありがとうございます。` / `Thank you for reaching out to To-do Calendar support.`
3. **문의 요지 한 줄** — 고객의 요청을 한 문장으로 되짚는다. 고객이 "제대로 읽혔다"를 확인하는 줄이다.
4. **답변** — 아래 유형별 내용.
5. **맺음** — 추가 문의를 환영하는 한 줄.
6. **서명** — `To-do Calendar サポート` / `To-do Calendar Support` / `To-do Calendar 지원팀`.

### 유형별 답변

- **기능 요청** — 요청을 접수해 검토 목록에 올렸다고 쓴다. 구현 여부·시기는 약속하지 않는다. 이슈 번호·내부 용어는 쓰지 않는다.
- **결함, 원인 확정** — 불편에 사과 → 확인된 사실 → 수정 예정. 버전·시기는 유저가 정해준 경우만 쓴다. 당장 쓸 우회가 있으면 번호 매긴 단계로.
- **결함, 정보 부족** — 사과 → 필요한 정보를 번호 매긴 질문으로 (위젯 종류·크기, 외부 캘린더 연동 여부, 재현 순서 등) → 이 메일에 회신 요청.
- **사용법** — 번호 매긴 단계. 앱 화면 라벨은 그 로케일 `Localizable.strings` 문구 그대로 인용한다.
- **계정 삭제 요청** — 선례가 있다: 삭제하면 일정·투두 데이터가 비가역적으로 지워진다, 결제 기록은 법령에 따라 보관한다, 구독은 자동 해지되지 않으니 iPhone 설정 > Apple 계정 > 구독에서 확인하라, 진행해도 되는지 이 메일에 회신해 달라. 삭제는 동의 회신을 받은 뒤에만 진행한다.

## 쓰지 않는 것

- 비밀번호·결제 수단 같은 민감 정보 요청
- 출시 일정·버전 약속 (유저가 명시한 경우 제외)
- GitHub 이슈 번호, 내부 코드명, 개발 진행 상태
