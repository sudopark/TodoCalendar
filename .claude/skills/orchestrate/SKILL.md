---
name: orchestrate
description: Use when executing decomposed large work as multiple PRs from one session — 분해된 하위 작업들을 한 세션이 서브에이전트 dispatch로 실행하고, 하위 작업 단위로 개별 PR(병렬 또는 stacked)을 내보내는 실행 모드. Triggers on kickoff 트랙 B 분해 후 같은 세션에서 실행 지시("이어서 실행하자", "오케스트레이션 하자"), 플랜 작성·실행 중 단일 PR로 감당 안 되는 규모로 판정됐을 때, 유저의 병렬·stacked PR 작업 지시. Does NOT trigger on 단일 PR 규모의 플랜 실행(superpowers subagent-driven-development·executing-plans), 하위 이슈를 별도 세션이 각자 킥오프하는 경로(kickoff 재진입), 분해 판단 자체(kickoff 트랙 B).
---

# Orchestrate — 멀티 PR 실행 오케스트레이션

컨트롤러(이 세션)가 분해된 sub-work들을 서브에이전트 dispatch로 실행하고, sub-work 단위로 개별 PR을 내보낸다. **컨트롤러는 분할·브리프·검수·PR 흐름 관리만 한다** — 코드는 서브에이전트가 만지고, diff·보고 전문은 파일로 주고받아 컨트롤러 컨텍스트를 오염시키지 않는다.

**SDD와의 관계**: 단일 PR 규모 플랜은 superpowers subagent-driven-development가 담당한다. 이 스킬은 그 위 스케일 — PR 여러 개짜리 작업의 실행 모드다. SDD의 태스크별 리뷰어 dispatch는 이 모드에 **없다** — 검증은 (a) 서브에이전트 자체 테스트, (b) 컨트롤러 검수(implement 스킬의 rules 항목별 스캔), (c) PR 단위 확인(유저, 지시 시 review 스킬)으로 수렴한다.

## 단위 정의 — 두 층을 혼동하지 않는다

- **sub-work = PR 하나.** 분해 출처는 kickoff 트랙 B 브리프 또는 유저와 합의한 분할. PR로서 의미 있는 서사(문제→접근)가 서는 크기로 가른다 — 자잘한 PR 남발은 이 스킬의 목적이 아니다.
- **dispatch = 서브에이전트 한 번이 완주 가능한 크기.** sub-work 하나는 1~N개의 순차 dispatch로 구현된다. sub-work을 PR 크기에 맞추고, dispatch를 완주 크기에 맞춘다 — 두 축은 독립이다.
- **dispatch가 넘치면 쪼개는 게 답이다 — "이어받기" 재dispatch 금지.** 브리프 작성 시점에 "한 번에 끝낼 수 있나"를 판단하고, 아니면 dispatch를 나눈다. 실행 중 넘침이 드러나면(중단·미완 보고) 잔여를 새 dispatch로 정의해 다시 브리프한다 — "하던거 계속해"로 잇지 않는다. 단, **검수 findings 교정을 위한 재개는 이어받기가 아니다**(§4-3) — 이어받기 금지는 크기 오판의 연장을 막는 것이고, findings 교정은 완결된 작업의 수정이라 원 에이전트 재개가 정당하다.

## 절차

### 1. 분할 확정

sub-work 목록·각 목표·의존 관계를 표로 정리해 유저 확인을 받는다. 각 sub-work에 이슈 번호가 필요하면(독립 PR 원칙) 이 시점에 유저 지시로 생성한다 — 커밋·PR은 `[#해당번호]`.

### 2. 실행 모드 판정 — 의존성 그래프

- **독립 sub-work → 병렬 가능.** 단 셋 다 충족할 때만: 파일 겹침 없음 / 각자 워크트리 확보(워크트리 tuist 함정 — 전용 워크스페이스 사용, 메인 워크트리 generated 재생성 주의) / **동시 진행 sub-work 2개 상한** (상한의 단위는 sub-work — 각 sub-work 내부 dispatch는 순차라, 동시에 활성인 워크트리·xcodebuild가 2개를 넘지 않게 하는 기준이다).
- **의존 sub-work → stacked 체인.** 앞 sub-work의 PR 머지를 기다리지 않는다 — 앞 브랜치를 베이스로 다음 sub-work을 진행하고, PR도 앞 브랜치를 base로 올린다.

### 3. Ledger — 컴팩션 생존 장부

`.superpowers/orchestrate/<상위이슈번호>/ledger.md`에 sub-work별 상태를 기록한다: 브랜치, base, dispatch 진행, PR#, 머지 여부. dispatch 완료·PR 생성·머지·rebase마다 갱신한다. 컴팩션 후엔 기억보다 ledger와 `git log`를 믿는다.

### 4. sub-work 실행 루프

1. **브랜치**: `features/` 브랜치를 base(develop 또는 앞 sub-work 브랜치)에서 딴다.
2. **브리프·dispatch**: implement 스킬을 invoke하고 §착수의 서브에이전트 dispatch 조항을 따른다 — rules 요지 발췌, 테스트 스킴, 구조 패턴, "갭 발견 시 추측 금지·보고 후 중단" 명시. 보고는 report 파일로 받는다 (전문을 컨트롤러 컨텍스트에 싣지 않는다).
3. **검수**: dispatch 보고마다 브리프에 실은 rules 조항 위반 여부를 항목별로 스캔하고, 테스트 통과를 확인한다. 결함이면 **원 서브에이전트를 재개해**(SendMessage) findings를 되돌린다 — 자기 작업 컨텍스트가 남아 있어 싸다. 재개가 불가하면 브리프·report 경로·findings를 실어 새 dispatch. 컨트롤러가 직접 고치지 않는다.
4. **커밋·PR**: 커밋은 서브에이전트가 논리 단위로 만든다(commit 스킬 컨벤션 승계). sub-work의 dispatch가 모두 끝나면 컨트롤러가 pr 스킬로 PR을 올린다 — stacked면 `gh pr create --base <앞 브랜치>`.
5. ledger 갱신 후 다음 sub-work으로.

### 5. stacked 체인 유지보수

- **앞 PR에 수정 커밋이 생기면**(유저 리뷰 반영 등) 뒷 브랜치를 앞 브랜치에 rebase하고 ledger에 기록한다.
- **앞 PR이 머지되면**(rebase merge라 커밋이 재작성된다) 머지된 브랜치를 base로 갖던 바로 뒤 sub-work만 처리한다: 브랜치를 `git rebase --onto develop <머지된 브랜치>`로 옮기고 PR base를 develop으로 바꾼다. 체인 더 뒤의 sub-work은 그대로 자기 앞 브랜치를 base로 유지한다.
- rebase 후 뒷 브랜치의 테스트 스킴을 재실행해 체인 파손을 즉시 잡는다.

### 6. 종료

모든 sub-work의 PR이 올라가면(머지는 유저 흐름) ledger를 정리하고 상위 이슈에 진행 요약 코멘트를 남긴다(issue 스킬). 미착수 잔여는 kickoff 분해 브리프의 "미분해 잔여"로 되돌린다 — 잃어버리지 않는 것이 불변 조건.

## 경계

- 컨트롤러가 코드를 직접 수정하지 않는다 — 검수에서 발견한 결함도 서브에이전트에 되돌린다(재개 우선, §4-3).
- 병렬 슬롯이 비어도 의존 체인을 앞질러 실행하지 않는다 — 앞 sub-work의 인터페이스가 확정되기 전의 뒷 작업은 재작업만 만든다.
- sub-work 실행 중 분할 자체가 틀렸다고 드러나면(경계 재조정 필요) 멈추고 유저와 분할을 재확정한다 — implement 스킬의 플랜 갭 보고 루프와 같은 원칙.

## 종료 기록 — skill_end

모든 sub-work의 PR 생성이 끝나 오케스트레이션이 마무리되는 시점에 `log-record.py skill_end`를 기록한다 (명령·compliance 규칙은 CLAUDE.md §1). 런당 1회 — sub-work 하나의 PR 생성은 런의 끝이 아니다. 런이 완주 못 하고 접히면(유저의 중단 선언) 그 시점에 partial + 사유로 기록한다.
