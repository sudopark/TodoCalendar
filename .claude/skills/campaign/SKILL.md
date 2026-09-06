---
name: campaign
description: Use when planning or evaluating multi-PR work (L·XL) — kickoff 가 사이즈를 L 이상으로 판정해 위임했을 때, 유저의 "작전계획 세워"·"캠페인 잡자" 직접 호출, DP 종결보고 접수 시점(평가 모드). Triggers on 작전계획, 캠페인, 전역계획, L·XL 사이즈 위임, DP 종결보고 접수(PR 생성) 시 평가·다음 DP 선택. Does NOT trigger on 단일 PR 계획(opord), DP 실행(orchestrate·implement), 사이즈 판정 자체(kickoff), 이슈 분해 없는 즉흥 구현.
---

# Campaign — 작전계획 작성·평가

## 1. 개요

**campaign.md 가 L 사이즈(PR 여러 개) 작업의 플랜이다.** 템플릿은 `docs/operations/templates/campaign.md` — 항목 밖 서술 금지, 해당 없는 항목은 "없음". 용어(DP·LOE·FRAGO·MOP/MOE·PIR/FFIR)는 템플릿 머리의 용어 줄이 정본이다.

- 진입은 양방향 — kickoff 사이즈 판정(L·XL)의 위임, 또는 유저의 직접 호출. **kickoff 가 안 돌았으면 먼저 invoke 한다** (정찰·게이트는 kickoff 소관 — 여기서 중복 구현하지 않는다).
- 분해 브리프는 이 계획이 갈음한다 — 7항 DP 목록이 리스트업이고, 미결 목록이 "미분해 잔여"다.
- 계획 파일은 `docs/operations/<상위이슈>/campaign.md` 로 커밋한다. 이슈 본문 = 이 파일 전문 + `<!-- progress -->` 블록 (§5).

**L 실행 루프** — 이 스킬은 루프의 양 끝(계획·평가)만 맡는다:

```mermaid
flowchart TD
    C[campaign<br/>campaign.md + 원장] --> D{다음 DP 선택}
    D --> DI[issue<br/>DP 하위 이슈 · 원장 착수]
    DI --> Q{착수 자격<br/>재가 · 선행 DP 머지 · 소유 범위}
    Q --> O[opord<br/>opord-DP.md · 확인보고 → 재가]
    O --> X[orchestrate<br/>dispatch 첫 보고 = 백브리프]
    X --> I[implement<br/>갭 → 단편명령 부록 D]
    I --> P[pr<br/>PR 본문 = 종결보고]
    P --> V[campaign 평가 모드<br/>MOP/MOE · 가정 · 원장<br/>단계 종료 조건 → 국면 전환]
    V -->|DP 남음| D
    V -->|없음| END([캠페인 종결])
```

M 은 kickoff → opord → implement → pr, S 는 kickoff → 구두지시 → implement → pr. XL 은 strategy.md 의 캠페인마다 위 루프.

## 2. 작성 모드

1. **작전구상 순서로 질문한다**: 전략 지침 → 문제 정의 → 최종상태 → 중심 → 접근 → 노력선 → 단계 → DP·소유 범위·인터페이스 계약 → 가정·위험 → 자원 → 평가. 기본안을 붙여 **일괄** AskUserQuestion — 답에 따라 계획이 바뀌는 것만 묻는다. 정찰(kickoff 탐색)로 알 수 있는 건 묻지 않는다.
2. **초안마다 정합성 검사**: 담당 없는 최종상태 관점 / 소유 범위 겹침 / 자원 충돌 / 시각 조건(종료 조건이 상태가 아니라 시점) / DP 크기(PR 하나로 며칠 안) / 선후 의존 / MOE≠MOP / 중심 반영. 하나라도 걸리면 해당 항목으로 되돌아간다.
3. **산출**: `campaign.md` 커밋 + 이슈 본문 미러(§5) + 미결 목록. **노력선·최종상태를 대신 정하지 않는다** — 참모는 채우는 걸 돕지, 결정은 유저 몫이다.

- DP 는 이슈 = PR 필수 — 원장의 이슈# 칸은 항상 채워지고, 커밋은 `[#DP이슈]`. DP 이슈 생성은 루프의 issue 단계에서 유저 지시로.
- 위임은 `docs/operations/templates/delegation.md` 상속 — 계획엔 좁히는 것만 적는다 (12항).

## 3. XL 전략 모드 — 미실효 (#1045 전까지)

캠페인 둘 이상이 한 목적을 공유하면 작성 모드의 1~3항(전략 지침·문제 정의·최종상태) + 캠페인 목록·원장만으로 `docs/operations/<이슈>/strategy.md` 를 만든다. 각 캠페인은 이 문서를 0항(전략 지침)으로 인용한다. 보고 배선(#1045)이 들어오기 전까지는 서식만 유효하다.

## 4. 평가 모드 — 종결보고 접수

DP 의 PR 이 생성돼 종결보고가 오면 (pr 스킬이 호출한다):

1. **MOP** — 종결보고 1항(최종상태 대조)로 DP 완료 판정.
2. **MOE** — 그 DP 가 담당한 관점(LOE 중간 목표)에 효과가 났는지 판정 — 과업 수행(MOP)과 별개다.
3. **가정 검증** — 종결보고 5항을 campaign.md 8항에 반영. 깨진 가정은 상향 규칙(delegation.md)대로.
4. **잔여 위험** — 종결보고 4항을 9항에 반영.
5. **원장 갱신** — 진행 파일(§5)의 해당 DP 행(상태·PR#·비고).
6. **단계 종료 조건 대조** — campaign.md 5항의 종료 조건이 상태로 충족됐으면 국면 전환: 다음 단계 DP 활성화, 주노력 재배분, 진행 파일의 현재 국면 갱신.
7. **다음 DP 선택** — 선행 DP 머지·소유 범위 기준으로 착수 가능한 DP 를 제안한다.

4항·가정·위험이 campaign.md **본문**을 고치는 경우(계획 개정)만 커밋이 생긴다 — 원장·국면은 진행 파일이라 커밋 없음. 개정·원장 갱신 후 이슈 본문 미러를 재조립한다.

**머지는 이 절차의 재실행이 아니다** — DP 가 머지되면 §5 원장을 `머지` 로 갱신하고, 종료 조건이 머지를 요구하는 단계(예: "모든 DP 머지")만 종료 조건을 재대조해 국면을 확정한다. MOP/MOE·가정·위험 반영은 종결보고 접수 시 1회로 끝난다.

## 5. 원장·진행 파일

- 경로: `.operations/<상위이슈>/campaign-progress.md` — gitignore 대상, 시점 무관 자유 갱신.
- 서식: `<!-- progress -->` 헤딩 + 현재 국면 줄 + 원장 표 `| DP | 상태 미착수/착수/실행/검토/머지 | 이슈# | 브랜치 | base | PR# | 비고 |`.
- 갱신 시점: DP 착수(issue 단계)·PR 생성·종결보고 접수·머지. 갱신마다 **이슈 본문 미러 재조립** — 본문 = `campaign.md` 전문 + 진행 파일 내용, `gh issue edit <상위이슈> --body-file` 로. 다른 세션·워크트리는 이슈 본문에서 상태를 복원한다.

## 6. 종료 기록 — skill_end

작성 모드는 campaign.md 저장·재가로, 평가 모드는 원장·미러 갱신 완료로 절차가 끝난다 — 그 시점에 `log-record.py skill_end` 를 기록한다 (명령·compliance 규칙은 CLAUDE.md §1). 평가 모드가 캠페인 종결(모든 DP 머지 + MOE)로 끝나면 상위 이슈 클로즈는 pr 스킬 머지 단계가 아니라 이 평가가 맡는다 — 클로즈 코멘트에 MOE 판정을 싣는다.
