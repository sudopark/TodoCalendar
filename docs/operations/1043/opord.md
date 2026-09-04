작전명령 — #1043 템플릿·opord 스킬 도입과 plan 스킬 삭제       초안: 에이전트   재가: 유저 2026-09-04   일자: 2026-09-04   상태: 종결
상위: 단독 (#1042 분해 브리프 리스트업 1번 — #1044·#1045 가 뒤따른다)

■ 확인보고
- 임무: plan 스킬을 지우고, 그 규정을 흡수한 `opord` 스킬과 템플릿 11개를 만들어 하네스 안의 plan 참조를 전부 opord 로 돌린다.
- 의도: 다음 이슈부터 작전명령 파일이 곧 플랜이 되고, 이슈 본문이 그 미러가 된다. 사이즈 판정·캠페인·보고 배선은 #1044·#1045 로 미룬다.
- 자율로 정할 것: 템플릿 파일의 영문 슬러그, opord SKILL.md 의 절 순서·문구, 치환 문구의 표현.
- 묻는 것: 없음.

1. 상황
   가. 정찰 결과
      - kickoff A-3(`.claude/skills/kickoff/SKILL.md:134-145`)이 plan 스킬을 invoke, A-4(:147-162)가 `<!-- kickoff-plan -->` 코멘트를 게시. §1(:35) 마커 3종, 트랙 A 선언 문구(:70) "플랜 작성 → 플랜 요약 코멘트", 코멘트 상한(:118) "A-4 플랜 요약".
      - `.claude/skills/plan/SKILL.md` 가 규정하는 것 — 해상도(:16-32), 결정 포인트 게이트 3종(:34-51), 필수 섹션 3(:53-75), 자족성 체크(:77-87), skill_end 기록 주체 writing-plans·brainstorming(:93-97).
      - implement `.claude/skills/implement/SKILL.md` — 착수 분기(:27-28), 플랜 갭 보고 루프(:101-107), brainstorming 기록 조건(:184).
      - 문구 참조 — commit(:12 "플랜의 커밋 시퀀스"), review(:55), agents/code-reviewer(:16), design(:46), CLAUDE.md §3(:64).
      - superpowers SDD `scripts/task-brief` 가 `^#+[ \t]+Task[ \t]+N` 헤딩으로 태스크를 잘라낸다. ledger 는 `.superpowers/sdd/<plan-basename>/progress.md` (gitignore).
      - `.gitignore:84-89` 는 `plans/`·`docs/superpowers/`·`.superpowers/` 만 — `docs/operations/` 는 커밋된다.
      - hooks·scripts 테스트의 `--name plan` 은 임의 문자열 픽스처, `triage-usage.py:62` 는 스킬 디렉토리 부재 시 `None` — 삭제에 무결합.
   나. 장애·마찰
      - 유력: opord SKILL.md 가 plan 규정 + 설계 세부 §5 + 템플릿 사용법을 다 담다 500줄 예산을 넘긴다.
      - 가장 위험: 치환 누락으로 `plan` 참조가 하네스에 남아 다음 세션이 없는 스킬을 invoke 한다.
   다. 상위 인용 (M)
      - 목적: #1042 — 계획·명령·보고 정형화, 상태 추적, 경계·버퍼.
      - 문제 정의: plan 스킬은 플랜을 gitignore 폴더에 두고 이슈엔 요약만 남겨 상태·경계·재량이 문서에 없다.
      - 최종상태: 작전명령이 곧 플랜, 이슈 본문이 미러, 템플릿 밖 서술 없음.
      - 가정: #1042 "템플릿" 코멘트가 서식 정본이다.
      - 위임: #1042 결정 6 권한표.
      - 제한: 분량 상한 없음 — 형식 준수만 (#1042 결정 7).
   라. 가정
      | ID | 가정 | 출처 | 깨지면 |
      |---|---|---|---|
      | A-1 | 하네스 밖(코드·docs/spec)에 plan 스킬 참조 없음 | 정찰 grep | 그 파일도 치환 대상에 추가 |
      | A-2 | SDD 는 `### Task N:` 헤딩만 맞으면 부록 A 를 그대로 실행한다 | task-brief 소스 | 부록 A 앞에 writing-plans 헤더 블록 추가 |

2. 임무 — 이 작업은 #1044 착수 전까지 opord 스킬·템플릿 11개를 도입하고 plan 스킬을 제거하여, 작전명령 파일이 플랜을 대체하게 한다.

3. 실시
   가. 의도
      - 목적: 다음 M 이슈가 `opord` 로 작전명령을 세우고 그 파일이 이슈 본문에 미러된다.
      - 핵심과업: (1) 템플릿이 #1042 코멘트와 일치 (2) opord 가 plan 의 규정을 하나도 잃지 않고 흡수 (3) 하네스 안 plan 참조 0건.
      - 최종상태: 동작 — `/opord`·kickoff A-3·writing-plans 시점에 opord 발동 / 코드·구조 — `docs/operations/templates/` 11 파일, `.claude/skills/opord/SKILL.md`, `.claude/skills/plan/` 부재 / 검증 — grep 0건, wc -l ≤500, 참조 경로 실존 / 외부 — 없음.
   나. 개념
      - 결정적 행동: opord SKILL.md 작성 (T-2).
      - 여건 조성: 템플릿을 먼저 확정해(T-1) 스킬이 참조할 경로를 고정.
      - 대안 경로: SKILL.md 가 500줄을 넘으면 부록 A 작성 규정(옛 plan 스킬의 해상도·결정 포인트 게이트·자족성 체크)만 `.claude/skills/opord/appendix-a-rules.md` 로 빼고 SKILL.md 가 1단계 참조 — 전환 조건: T-2 초안 wc -l > 500.
      - 단계: T-1 → T-2 → T-3 순차 (각 커밋 = 단계 종료).
   다. 과업
      - T-1: 템플릿 11개를 `docs/operations/templates/` 에 두어, opord·후속 스킬이 같은 경로를 참조하게 한다.
      - T-2: opord 스킬을 신설하여, 작전명령 초안·재가·본문 미러 절차와 plan 규정을 한 곳에 둔다.
      - T-3: plan 스킬을 삭제하고 하네스 8곳의 참조를 opord 로 돌려, 다음 세션이 없는 스킬을 부르지 않게 한다.
   라. 협조지시
      - 개시 조건: 재가.
      - 제한: 템플릿 본문은 #1042 코멘트 서식을 바꾸지 않는다 (서식 정본이 이슈에 있고 #1044·#1045 가 같은 걸 참조). kickoff 트랙 판정·트랙 B·orchestrate·pr·issue 는 만지지 않는다 (#1044 소유).
      - 위임 범위: 권한표 기본값. 좁히는 것 — `.claude/skills/opord/` 밖 파일 신설은 사전승인 (대안 경로의 `appendix-a-rules.md` 는 예외로 사전 승인됨).
      - 수용 위험: opord 절차 문구는 첫 실측(#1044 착수) 전엔 검증 불가 — 실측 후 조정을 #1042 close 조건에 이미 실었다.
      - 버퍼: 자율 등급 + 아래 우발계획.
      - 즉시보고 조건: FFIR-1 정찰 밖 plan 참조 발견 → D-1 / FFIR-2 rules·CLAUDE.md 에 없는 배치 판단(템플릿 위치·스킬 소유가 갈리는 항목) → D-2 (하네스 갭).
      - 결정지점
        | ID | 결정 | 판단 정보 | 시한 | 미결 시 기본 행동 |
        |---|---|---|---|---|
        | D-1 | 발견된 참조를 이번 PR 에서 치환할지 | 파일이 스코프 안인지 | T-3 중 | 스코프 안이면 치환, 밖이면 부록 D 기록 후 #1044 로 |
        | D-2 | 배치 판단 | 해당 조항 부재 확인 | 발견 즉시 | 중단 후 유저 결정, 종결보고 8항 |
      - 우발계획
        | 조건 | 행동 | 결심자 | 상향 |
        |---|---|---|---|
        | T-2 초안 > 500줄 | 대안 경로(appendix-a-rules.md 분리) | 에이전트 | 없음 |
        | 템플릿 코멘트와 설계 세부 코멘트가 서로 어긋남 | 중단, 유저에게 어느 쪽이 정본인지 확인 | 유저 | #1042 코멘트 정정 |

4. 검증·자원
   - 테스트 스킴: 없음 (문서·하네스 변경 — implement 완료 판정 "유닛테스트 커버 밖" 경로).
   - 검증 사다리: (1) `grep -rn -e 'plan 스킬' -e 'skills/plan' -e 'kickoff-plan' .claude CLAUDE.md` → 0건 (2) `wc -l .claude/skills/opord/SKILL.md` ≤ 500 (3) opord SKILL.md 가 참조하는 경로 전부 `ls` 로 실존 (4) 템플릿 11 파일이 #1042 코멘트 블록과 diff 없음 (5) PR 후 harness-review.
   - 모델 티어: 부록 C. 병렬 슬롯·워크트리: 이 세션 단독, 현 워크트리.
   - 외부 자원: 없음.

5. 보고
   - 즉시: FFIR-1·FFIR-2, 우발 2건, 가정 A-1·A-2 붕괴.
   - 정기: 태스크 완료마다 부록 E 갱신.
   - 유저 부재 시: 의도 안이면 기본안으로 계속, D-2 면 중단.
   - 종결 조건: 검증 사다리 (1)~(4) 통과 + PR 생성 + 종결보고.

## 부록 A. 태스크 상세

### Task 1: 템플릿 11개

**Files:**
- Create: `docs/operations/templates/strategy.md` · `campaign.md` · `opord.md` · `frago.md` · `verbal-order.md` · `report-confirmation.md` · `report-backbrief.md` · `report-immediate.md` · `report-periodic.md` · `report-after-action.md` · `report-debrief.md`

**Interfaces:**
- Produces: 위 11 경로 — Task 2 의 opord SKILL.md 와 #1044·#1045 가 그대로 참조.

- [ ] Step 1: `gh api repos/sudopark/TodoCalendar/issues/comments/5535183844 --jq .body` 로 #1042 "템플릿" 코멘트를 받아 스크래치패드에 저장.
- [ ] Step 2: 코멘트의 각 `####` 블록을 파일 하나로 옮긴다 — 코드펜스 안 서식 + 그 아래 불릿(사용 노트)까지. 보고 6종은 "### 보고" 아래 `####` 마다 한 파일. 파일 머리는 `# <한글 명칭> (<군 용어>)` 한 줄, 그 아래 원문 그대로.
- [ ] Step 3: `opord.md` 템플릿의 부록 A 줄을 `부록 A. 태스크 상세 — ### Task N: <제목> 헤딩(SDD task-brief 호환)·Files·Interfaces·체크박스 Step, 시그니처·경로·동형 file:line·엣지 케이스·테스트 케이스 이름` 으로 고친다 — 서식 변경이 아니라 헤딩 규격 명시다.
- [ ] Step 4: 검증 — 파일 11개 존재, 각 파일 코드펜스 내용이 코멘트 블록과 `diff` 0.
- [ ] Step 5: 커밋 (부록 B 커밋 2).

### Task 2: opord 스킬

**Files:**
- Create: `.claude/skills/opord/SKILL.md`
- Test: 없음 — 검증은 wc -l·참조 실존·description 규격 육안.

**Interfaces:**
- Consumes: Task 1 경로. `.claude/skills/plan/SKILL.md` 규정 원문(:16-32, :34-51, :53-75, :77-87, :93-97).
- Produces: 스킬명 `opord`, 마커 없음(본문 미러), 상태 헤더 값 `초안/재가/실행/종결`. Task 3 의 치환 문구가 이 이름·경로를 쓴다.

- [ ] Step 1: frontmatter. `name: opord`, description 은 "Use when writing an operation order (작전명령) for a single-PR issue or one DP in this project — kickoff A-3 전환, `/opord` 명시 호출, superpowers:writing-plans 를 invoke 하려는 그 자리(brainstorming 종점 포함) 전부. Triggers on '작전명령 세워', '계획 세워', 'opord', writing-plans 발동 시점. Does NOT trigger on 캠페인·전략(campaign), 실행(implement·orchestrate), 이슈 분해(kickoff)". 워크플로우 요약 금지 (harness-reviewer :22).
- [ ] Step 2: 본문 절 순서 — (1) 개요: 작전명령 = 플랜, writing-plans 대체 관계(plan/SKILL.md:8 문장을 "대체한다"로 뒤집는다 — 문서 구조는 템플릿이 이끌고 writing-plans 의 태스크 스텝 규격·No Placeholders 만 부록 A 에 남긴다) (2) 진입: M 이슈 또는 DP 하나, kickoff 안 돌았으면 먼저 invoke, 입력 = 스펙 브리프(M) 또는 DP ID + campaign.md 인용(L — #1044 전까진 M 경로만 실효) (3) 절차 8단계: #1042 설계 세부 §5 opord 1~8 을 번호 목록으로 (4) 부록 A 규정 = plan §해상도(:16-32 — code block 면제 조항 포함)·§결정 포인트 게이트 3종(:34-51)·자족성 체크(:77-87) 를 원문 이관 (5) 부록 B 커밋 시퀀스 = plan :61-65, 부록 C 모델 티어 = plan :67-75 (6) 상태 전이 표: 초안(초안 저장)·재가(유저 확인, 이 스킬)·실행(implement 착수)·종결(pr — #1044 배선 전까지 수동) (7) 저장·미러: `docs/operations/<이슈>/opord.md`(DP 면 `opord-<DP>.md`), 재가 직후 `gh issue edit <N> --body-file <경로>`, 갱신 커밋은 그 이슈의 PR (8) 부록 E ↔ SDD ledger: 부록 E 는 계획 층(태스크 완료·커밋 sha·보고, GitHub 미러), SDD `progress.md` 는 실행 층(ruling·복구) — 둘 다 쓴다 (9) 종료 기록: plan :93-97 원문 이관 (writing-plans·brainstorming 기록 주체).
- [ ] Step 3: 범위 명확성 전제(plan :10-14)는 (2) 진입 절에 흡수 — "작성 중 태스크 확정 불가·경계 불명이면 kickoff 게이트로 되돌린다".
- [ ] Step 4: 검증 — `wc -l` ≤ 500 (초과 시 3-나 대안 경로), 참조 경로 `ls`, description 에 워크플로우 요약 없음.
- [ ] Step 5: 커밋 (부록 B 커밋 3).

### Task 3: plan 삭제와 참조 치환

**Files:**
- Delete: `.claude/skills/plan/SKILL.md` (디렉토리째)
- Modify: `.claude/skills/kickoff/SKILL.md:35` 마커 3종 → 2종(`kickoff-plan` 삭제) / `:70` 트랙 A 선언 "플랜 작성 → 플랜 요약 코멘트" → "작전명령 작성(opord) → 이슈 본문 미러" / `:118` 코멘트 상한에서 "A-4 플랜 요약" 제거(둘뿐) / `:134-145` A-3 "plan 스킬" → "opord 스킬", 플랜 생략 4조건 유지 + 생략 시 구두지시 템플릿(`docs/operations/templates/verbal-order.md`) 5문장 코멘트로 A-4 갈음 / `:147-162` A-4 → "작전명령이 재가 시 이슈 본문에 미러된다(opord 스킬) — 요약 코멘트 없음" 한 줄로 교체(헤딩 유지).
- Modify: `.claude/skills/implement/SKILL.md:27` "플랜 있음" → "작전명령 있음 (부록 A 가 태스크 순서)" + 착수 시 상태 헤더 `실행` 갱신 / `:101-107` 플랜 갭 보고 루프 — 유저 반문·후속 정리는 유지하고 기록 자리를 부록 D 단편명령(`frago.md` 서식)으로, 사후보고 등급 결정은 종결보고 7항 누적 한 줄 추가 / `:184` "plan 스킬이 이미 기록했다" → "opord 스킬이".
- Modify: `.claude/skills/commit/SKILL.md:12` "플랜의 커밋 시퀀스" → "작전명령 부록 B" / `.claude/skills/review/SKILL.md:55`·`.claude/agents/code-reviewer.md:16` "스펙 브리프·플랜" → "스펙 브리프·작전명령(`docs/operations/<이슈>/opord.md`)" / `.claude/skills/design/SKILL.md:46` "이슈 본문과 플랜의 입력" → "작전명령의 입력" / `CLAUDE.md:64` 행 → `| 작전명령 작성 (M·DP 플랜) | opord 스킬 |`.

**Interfaces:**
- Consumes: Task 2 스킬명·경로, Task 1 `verbal-order.md`·`frago.md`.

- [ ] Step 1: `git rm -r .claude/skills/plan`.
- [ ] Step 2: 위 Modify 목록 순서대로 편집. 각 파일은 편집 전 Read.
- [ ] Step 3: 검증 — `grep -rn -e 'plan 스킬' -e 'skills/plan' -e 'kickoff-plan' -e '플랜 요약' .claude CLAUDE.md` 0건. `grep -rn '플랜' .claude/skills/kickoff .claude/skills/implement` 잔여는 "플랜 생략"·"플랜 갭" 같은 일반명사만인지 육안.
- [ ] Step 4: 커밋 (부록 B 커밋 4).

## 부록 B. 커밋 시퀀스 (변경은 사후보고)

1. `[#1043] 작전명령 초안 — 템플릿·opord 스킬·plan 삭제 순서` — 이 파일 (재가 후 상태 `재가`로 갱신해 amend 없이 커밋)
2. `[#1043] 작전 문서·보고 템플릿 11개를 docs/operations/templates 에 둔다` = Task 1
3. `[#1043] opord 스킬이 작전명령 초안·재가·본문 미러와 plan 규정을 맡는다` = Task 2
4. `[#1043] plan 스킬을 삭제하고 kickoff·implement·commit·review·design·CLAUDE.md 접점을 opord 로 잇는다` = Task 3
5. 부록 E 최종 갱신·종결보고는 PR 생성 직전 커밋 4 에 흡수 (별도 커밋 없음)

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| Task 1 | 하위 (haiku급) | 코멘트 → 파일 transcription, 경로 확정 |
| Task 2 | 표준 (sonnet급) | plan 원문·설계 세부·템플릿 세 소스를 한 문서로 통합 — 결정은 위에 확정, 문구 조율만 |
| Task 3 | 표준 (sonnet급) | 8파일 문구 치환 + 잔여 grep 판단 |

실행은 이 세션 인라인(executing-plans) — 설계 맥락이 이 세션에 있고 dispatch 이득이 없다.

## 부록 D. 단편명령 누적

없음

## 부록 E. 진행

| 태스크 | 상태 | 커밋 | 보고 |
|---|---|---|---|
| Task 1 | 완료 | 36007b4e | 정찰 그대로, 11파일 |
| Task 2 | 완료 | b7d74406 | SKILL.md 136줄 — 대안 경로 미전환 |
| Task 3 | 완료 | 115de31a | 검증 grep 0건, 하네스 밖 참조 없음(A-1 확인) |
