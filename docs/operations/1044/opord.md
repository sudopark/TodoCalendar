# 작전명령 — #1044 campaign 스킬과 kickoff·orchestrate·pr 접점

> 용어 — DP: 결정적 지점(작전명령 하나 = PR 하나) · LOE: 노력선(최종상태 한 관점을 담당하는 줄기) · FRAGO: 단편명령 · MOP / MOE: 과업 수행 여부 / 효과 발생 여부 · PIR / FFIR: 즉시보고 조건 중 환경·외부 정보 / 아군·내부 정보

작전명령 — #1044 campaign 스킬과 kickoff·orchestrate·pr 접점       초안: 에이전트   재가: 유저 2026-09-06   일자: 2026-09-06
상위: 단독 (#1042 분해 브리프 리스트업 2번 — 선행 #1043 은 PR #1046 으로 머지·클로즈, #1045 가 뒤따른다)

> 헤더에 `상태:` 칸이 없다 — 이 명령이 도입하는 진행 층 분리의 셀프 적용이다. 상태·태스크 진행은 `.operations/1044/progress.md`(gitignore)에 살고 이슈 본문 `<!-- progress -->` 블록으로 미러된다.

■ 확인보고
- 임무: campaign 스킬을 신설하고 kickoff·orchestrate·pr·issue·opord·implement 접점을 이어, L 작업이 작전계획–원장–종결보고 루프로 돌고 진행 상태가 커밋 없이 이슈에서 추적되게 한다.
- 의도: 다음 L 이슈부터 kickoff 가 사이즈를 판정해 campaign 으로 위임하고, 이번에 손으로 한 종결 처리(이슈 클로즈·보드 Done·상위 원장 갱신)가 pr 스킬 배선으로 자동화된다.
- 자율로 정할 것: campaign description 트리거 문구, 각 스킬의 절 번호 재배열, 진행 파일 서식(opord 상태·부록 E 표 / campaign 원장·국면), 이슈 본문 미러 재조립 방식.
- 묻는 것: 없음.

## 1. 상황

가. 정찰 결과 (kickoff 탐색 + 이번 세션 재확인, file:line 은 2026-09-06 기준)
   - kickoff `SKILL.md:55-72` 트랙 A/B 판정과 판정 선언 문구, `:64` 복귀 판정, `:118` 코멘트 상한(A-2·B-2 마커 2종), `:138-145` 작전명령 생략(S) 4조건 + 구두지시 갈음, `:153-197` 트랙 B(B-1 분해 게이트 / B-2 `<!-- kickoff-breakdown -->` 브리프 / B-3 재진입 3경로 — "상위 이슈에 커밋" 경로 포함).
   - orchestrate `SKILL.md` — §1 분할 확정(유저 확인·이슈 생성), §3 ledger `.superpowers/orchestrate/<상위이슈번호>/ledger.md`, §6 종료(진행 요약 코멘트·미분해 잔여 반환)가 대체 대상. §2 실행 모드 판정·§4 sub-work 실행 루프·§5 stacked 유지보수·경계·skill_end 는 존치. description 이 "kickoff 트랙 B 분해 후"를 트리거로 명시 — 사이즈 체계로 갱신 필요.
   - opord `SKILL.md` §6 상태 전이 표(주체: 이 스킬/implement/pr — "배선 전까지 수동"), §7 저장·미러(:117-121 실행 중 갱신을 브랜치 커밋으로 규정 → #1043 에서 상태 전용 커밋 e1d38c9b 발생), §8 부록 E ↔ SDD ledger. 템플릿 `docs/operations/templates/opord.md:6` 헤더 `상태:` 칸, `:35` 부록 E 줄.
   - pr `SKILL.md` — 본문 절에 종결보고 배선 없음. 머지·정리 절 "이후 단계(Done 등) 이동은 유저가 보드에서 직접 한다" — 2026-09-06 유저 교정으로 뒤집힘(에이전트 수행). 이슈 클로즈·상위 진행 기록 조항도 부재 — 같은 날 correction 2건이 실증.
   - issue `SKILL.md:14` 하위 이슈 링크 `상위 이슈: #N (분해 브리프의 리스트업 k번)`.
   - implement `SKILL.md:27` "작전명령 있음" 분기 — 헤더 `상태:` `실행` 갱신 + 부록 E 갱신을 규정 (진행 층 이동 대상), `:103-108` 갭 보고 루프의 부록 D 누적은 유지.
   - CLAUDE.md §3 표에 campaign 행 없음. `.gitignore:89` `.superpowers/` — `.operations/` 미등재.
   - 정본 소스: #1042 "설계 세부" 코멘트(5534660380) — §2 사이즈 판정 순서·§3 상향 규칙·§4 권한표·§5 campaign/opord 절차·L 실행 루프·§6 보고 배선 표·§7 자기점검. 템플릿 코멘트(5535183844)는 #1043 이 파일화 완료.
   - campaign.md 템플릿 15항 존재 — 7(DP 목록: 정의)·15(원장: 상태) 분리, 사용 노트 "이슈 본문은 이 파일의 미러", M 은 이 문서 안 만듦.

나. 장애·마찰
   - 유력: campaign SKILL.md 가 설계 세부 §5 절차 + 평가 모드 + 원장·국면·진행 파일 규정을 다 담다 500줄 예산을 넘긴다.
   - 가장 위험: 진행 층 이동 후 opord·implement·pr 세 스킬의 갱신 규정이 서로 어긋나(한쪽은 커밋, 한쪽은 진행 파일) 다음 세션이 stale 한 쪽을 따른다.

다. 상위 인용 (M)
   - 목적: #1042 — 계획·명령·보고 정형화, 상태 추적, 국면 관리, 경계·버퍼.
   - 문제 정의: L 작업의 계획·원장 자리가 없고(orchestrate ledger 는 세션 장부), 진행 상태가 커밋에 실리거나(1043 선례) 아예 안 남는다(이슈 클로즈·보드 누락 실증).
   - 최종상태: 사이즈별 프로세스 표(XL/L/M/S)대로 스킬이 배선되고, 진행 상태는 커밋 밖·이슈 안.
   - 가정: #1042 설계 세부·템플릿 코멘트가 규정 정본이다.
   - 위임: #1042 결정 6 권한표 (delegation.md 로 이관).
   - 제한: 분량 상한 없음 — 형식 준수만 (#1042 결정 7). 봇 계정·@멘션 배선은 #1045.

라. 가정
   | ID | 가정 | 출처 | 깨지면 |
   |---|---|---|---|
   | A-1 | #1042 설계 세부 §5 절차 1~5 가 campaign SKILL.md 규정의 정본이다 | 상속 (#1042 코멘트) | 해당 절 재작성 후 유저 재확인 |
   | A-2 | SDD ledger(`.superpowers/sdd/`)는 superpowers 플러그인 소관이라 존치 — `.operations/` 진행 파일과 층이 다르다 (유저 요구는 우리 진행 층의 superpowers 의존 제거) | 미확인 질문 대체 | opord §8 을 진행 파일 단일 층으로 재작성 |
   | A-3 | 부록 A Step 체크박스의 완료 표시는 이슈 본문 미러에서 [x] 갱신 — 커밋 층 파일은 안 건드린다 | 미확인 질문 대체 (2026-09-06 교정 "체크 안 하냐" 반영) | 갱신 주체·자리 유저 재결정 |
   | A-4 | pr 머지 단계의 이슈 클로즈·보드 Done 이동·상위 원장(진행) 갱신도 이번 배선 스코프다 | 신규 (2026-09-06 correction 2건) | 해당 조항만 #1045 로 이월 |

## 2. 임무

이 작업은 #1045 착수 전까지 campaign 스킬을 도입하고 kickoff·orchestrate·pr·issue·opord·implement 접점을 연결하여, L 작업이 작전계획–원장–종결보고 루프로 돌고 진행 상태가 커밋 없이 이슈 본문에서 추적되게 한다.

## 3. 실시

가. 의도
   - 목적: 다음 L 이슈가 campaign.md 7 DP 목록·15 원장으로 계획·추적되고, M/S 의 진행·종결 처리가 수동 누락 없이 배선으로 돈다.
   - 핵심과업: (1) campaign 이 설계 세부 §5 절차를 하나도 잃지 않고 담는다 (2) kickoff 사이즈 판정이 설계 세부 §2 순서 그대로다 (3) 진행 층 이동 후에도 다른 세션이 이슈 본문만으로 상태를 복원할 수 있다 (4) orchestrate 잔여 조항이 campaign 과 무모순이다 (5) 하네스 안 dangling 참조 0건.
   - 최종상태: 동작 — kickoff 가 사이즈를 선언하고 L 이상을 campaign 에 위임, pr 이 종결보고·진행 종결·이슈 클로즈·보드 Done 을 수행 / 코드·구조 — campaign SKILL.md ≤500줄, 권한표 정본 delegation.md, 진행 층 `.operations/`(gitignore) / 검증 — 참조 grep 0건, CLAUDE.md §3 표 짝 배선 / 외부 — 이슈 본문 = 계획 미러 + `<!-- progress -->` 블록.

나. 개념
   - 결정적 행동: campaign SKILL.md 신설 — 나머지 과업 전부가 그 접점이다.
   - 여건 조성: 템플릿·gitignore 정비(T-1)가 선행 — campaign·opord 가 참조할 delegation.md 와 진행 층 경로가 먼저 있어야 한다.
   - 대안 경로 + 전환 조건: campaign SKILL.md 가 500줄을 넘으면 본문 + `references/` 분할로 전환.
   - 단계: 템플릿(T-1) → campaign(T-2) → 접점 개정(T-3~T-6). T-3~T-6 은 상호 독립 — 순서는 부록 B 커밋 순.

다. 과업
   - T-1: delegation.md 를 신설하고 campaign.md·opord.md 템플릿의 상태·부록 E 를 진행 층으로 옮겨, 계획 문서를 커밋 불변으로 만든다.
   - T-2: campaign 스킬을 도입하여 L·XL 의 계획 작성·평가 모드·원장을 맡긴다.
   - T-3: opord 스킬의 상태·미러 규정을 진행 파일 기준으로 교체하여 상태 전용 커밋을 없앤다.
   - T-4: kickoff 의 트랙 판정을 사이즈 판정으로 교체하여 L 이상을 campaign 에 위임한다.
   - T-5: orchestrate 의 분할 확정·ledger·종료를 campaign 참조로 대체하여 실행 전용 스킬로 좁힌다.
   - T-6: pr·issue·implement·CLAUDE.md 접점을 연결하여 종결보고·DP 좌표·진행 갱신을 배선한다.

라. 협조지시
   - 개시 조건: 없음 — 선행 #1043 머지·클로즈 완료.
   - 인터페이스 계약: #1045 가 이어받을 것 — 보고 배선 표의 봇 코멘트·@멘션 열은 이번에 배선하지 않고 "미실효 (#1045)" 표기만. XL 전략 모드도 같다.
   - 제한: 봇 계정·멘션 배선 금지 (#1045 소유 범위 — 겹치면 충돌) / 머지된 `docs/operations/1043/opord.md` 수정 금지 (선례 보존, 스펙 브리프 확정) / superpowers 플러그인 파일 수정 금지 (외부 소유).
   - 위임 범위: delegation.md 기본값 그대로 — 좁히는 것 없음.
   - 수용 위험: 사이즈 판정·권한표 문언이 실측 전 — 첫 L 작업에서 조정 가능성 (수용, 조정은 FRAGO).
   - 즉시보고 조건: FFIR-1 개정 중 스킬 간 조항 모순 발견(어느 문언이 정본인지 rules 에 없음) → D-1.
   - 결정지점 | D-1 | 모순 시 정본 문언 선택 | 충돌 조항 쌍 인용 | 발견 즉시 | 미결 시 기본: #1042 설계 세부 코멘트 우선 |
   - 우발계획 | campaign SKILL.md 500줄 초과 | 본문 + references/ 분할 | 실행자 | 상향 없음 |

## 4. 검증·자원

- 테스트 스킴 없음 — 하네스 md·gitignore 만. 검증 사다리 대신: (1) 참조 무결 grep (부록 A 각 태스크 Step) (2) `wc -l` ≤500 (3) 짝 배선 — CLAUDE.md §3 표 ↔ campaign 스킬 신설 (CLAUDE.md §1 짝 규칙) (4) 진행 파일 → 이슈 미러 재조립 실연 1회 (이 이슈 자신으로).
- 실행: 이 세션 인라인 (superpowers:executing-plans) — 설계 맥락이 이 세션에 있고 dispatch 이득이 없다 (#1043 선례). 워크트리 이동 없음, 작업 브랜치 `features/1044-campaign-skill` 을 origin/develop 에서 딴다.
- 모델 티어: 부록 C.

## 5. 보고

- 즉시: FFIR-1 (조항 모순) → D-1. 가정 A-1~A-4 붕괴. 하네스 갭.
- 정기: 태스크 완료마다 `.operations/1044/progress.md` 갱신 + 이슈 본문 미러 재조립.
- 유저 부재 시: 의도 안이면 기본안으로 계속, D-1 이면 중단.
- 종결 조건: 검증 (1)~(4) 통과 + PR 생성 + 종결보고 (`report-debrief.md` 1·2·3·10 → PR 본문 — T-6 이 배선하는 규정의 셀프 적용).

## 부록 A. 태스크 상세

### Task 1: 템플릿·gitignore — 진행 층 분리의 기반

**Files:**
- Create: `docs/operations/templates/delegation.md`
- Modify: `docs/operations/templates/campaign.md` · `docs/operations/templates/opord.md` · `.gitignore`

**Interfaces:**
- Produces: `delegation.md` 경로 (T-2 campaign·T-3 opord 가 참조), `.operations/<이슈>/progress.md`·`.operations/<상위이슈>/campaign-progress.md` 경로 규약, 템플릿에서 상태 칸·부록 E 제거된 서식.

- [ ] Step 1: `delegation.md` 신설 — #1042 설계 세부 §4 권한표(4열 표 10행)와 §3 상향 규칙(6행 표)을 원문 이관. 파일 머리 `# 위임 권한표 (Delegation) — 기본값` 한 줄 + "campaign.md 12항·opord 3-라 는 이 표를 상속하고 좁히기만 한다. 실측 후 조정은 이 파일 개정으로" 사용 노트.
- [ ] Step 2: `campaign.md` — 헤더 줄에서 `현재 국면: <n>단계` 를 빼고 15항 원장 줄에 `→ .operations/<상위이슈>/campaign-progress.md (원장·현재 국면 — 커밋되지 않음, 이슈 본문 <!-- progress --> 블록으로 미러)` 로 교체. 12항을 `12. 위임 — delegation.md 상속, 좁히는 것만 기재` 로 축약. 사용 노트의 "15 는 상태" 문장을 진행 파일 기준으로 갱신.
- [ ] Step 3: `opord.md` 템플릿 — 헤더 `:6` 에서 `상태: 초안/재가/실행/종결` 칸 제거. `:35` 부록 E 줄을 `부록 E 없음 — 진행(상태·태스크·커밋 sha·보고)은 .operations/<이슈>/progress.md, 이슈 본문 <!-- progress --> 블록으로 미러` 로 교체.
- [ ] Step 4: `.gitignore:89` (`.superpowers/`) 다음 줄에 `.operations/` 추가.
- [ ] Step 5: 검증 — `grep -rn '부록 E' docs/operations/templates/` 가 진행 파일 참조만 남는지, `git check-ignore .operations/x` 통과.
- [ ] Step 6: 커밋 (부록 B 커밋 2).

### Task 2: campaign 스킬 신설

**Files:**
- Create: `.claude/skills/campaign/SKILL.md`

**Interfaces:**
- Consumes: Task 1 의 `delegation.md`·진행 파일 경로 규약, `docs/operations/templates/campaign.md`·`strategy.md`·`report-debrief.md`.
- Produces: 스킬명 `campaign`, 평가 모드 진입 규약(종결보고 접수 시) — T-4 kickoff 위임·T-5 orchestrate 참조·T-6 pr 종결보고 전달이 이 이름을 쓴다.

- [ ] Step 1: frontmatter — `name: campaign`, description 은 "Use when planning or evaluating multi-PR work (L·XL) — kickoff 사이즈 판정 L 이상 위임, '작전계획 세워' 직접 호출, DP 종결보고 접수(평가 모드). Does NOT trigger on 단일 PR 계획(opord), 실행(orchestrate·implement), 사이즈 판정 자체(kickoff)" 취지로 — 워크플로우 요약 금지.
- [ ] Step 2: 본문 절 — (1) 개요: campaign.md = L 의 플랜, 진입 양방향(kickoff 판정 후 / 직접 호출), kickoff 안 돌았으면 먼저 invoke (2) 작성 모드: 설계 세부 §5 campaign 1~3 원문 기반 — 작전구상 순서 질문(기본안 붙여 일괄, 답에 따라 계획이 바뀌는 것만) → 초안 정합성 검사 8항 → 산출(campaign.md 커밋 + 이슈 본문 미러 + 미결 목록). "노력선·최종상태를 대신 정하지 않는다" 유지 (3) XL 전략 모드: 1~3항 + 캠페인 목록·원장 → strategy.md — "미실효 (#1045 전까지)" 표기 (4) 평가 모드: 종결보고 접수 → MOP → MOE → 가정 검증(8) → 잔여 위험(9) → 원장(15) 갱신 → 단계 종료 조건 대조 → 전환 시 다음 단계 DP 활성화·주노력 재배분·국면 표시 → 다음 DP 선택 (5) 원장·진행 파일: `.operations/<상위이슈>/campaign-progress.md` 서식(15항 원장 표 + 현재 국면 줄) + 이슈 본문 미러 재조립 (6) 위임: delegation.md 참조 (7) 종료 기록 skill_end.
- [ ] Step 3: L 실행 루프 mermaid(설계 세부 §5)를 (1) 개요에 이관 — 각 노드가 스킬명과 일치하는지 대조.
- [ ] Step 4: 검증 — `wc -l` ≤500 (초과 시 3-나 대안 경로), 참조 경로 전부 `ls` 실존, description 에 워크플로우 요약 없음.
- [ ] Step 5: 커밋 (부록 B 커밋 3).

### Task 3: opord 스킬 — 진행 층 이동

**Files:**
- Modify: `.claude/skills/opord/SKILL.md`

**Interfaces:**
- Consumes: Task 1 템플릿 서식(상태 칸 없음), 진행 파일 경로 규약.
- Produces: §6·§7·§8 개정 문언 — T-6 implement·pr 개정이 이 규정과 무모순이어야 한다 (1-나 "가장 위험" 완화 지점).

- [ ] Step 1: §6 상태 전이 — "헤더 `상태:` 값" 전제를 "진행 파일 `상태:` 값"으로 교체. 표의 4행·주체는 유지하되 종결 행 "배선 전까지는 수동 갱신" → "pr 스킬이 수행" (T-6 배선 후 문언). 전이마다 이슈 본문 미러 재조립을 명시.
- [ ] Step 2: §7 저장·미러 — "실행 중 갱신(부록 D·E, 상태)은 같은 브랜치에 커밋" 문장을 교체: 커밋 층(1~5절·부록 A~D)은 초안·FRAGO 때만 커밋, 진행(상태·부록 E 상당)은 `.operations/<이슈>/progress.md` 에 자유 갱신·커밋 금지. 이슈 본문 = 커밋 층 전문 + `<!-- progress -->` 블록 — 재조립은 `gh issue edit <N> --body-file` (opord.md + progress.md 연결). 부록 A Step 체크박스 완료 표시는 이슈 본문 미러에서만 [x] (가정 A-3).
- [ ] Step 3: §8 — "부록 E" 를 progress.md 서식 규정으로 교체(태스크 | 상태 | 커밋 | 보고 표 + 명령 상태 줄). SDD ledger 는 실행 층으로 존치 (가정 A-2) — 층 구분 문장 유지.
- [ ] Step 4: 검증 — `grep -n '상태:' .claude/skills/opord/SKILL.md` 잔여가 진행 파일 기준 문언뿐인지, `grep -rn '부록 E' .claude/skills/` 가 progress.md 규정을 가리키는지.
- [ ] Step 5: 커밋 (부록 B 커밋 4).

### Task 4: kickoff — 사이즈 판정

**Files:**
- Modify: `.claude/skills/kickoff/SKILL.md`

**Interfaces:**
- Consumes: Task 2 스킬명 `campaign`, #1042 설계 세부 §2 판정 순서.
- Produces: 사이즈 선언 문구 — 유저가 보는 판정 선언 형식.

- [ ] Step 1: §3(:55-72) 트랙 A/B 판정을 사이즈 판정으로 교체 — 설계 세부 §2 의 5단계 판정(위에서부터 첫 "예": XL → L → M → 단편명령 → S)을 원문 이관, "승격만 허용" 포함. 판정 선언 문구 4종: XL·L → "campaign 위임 — 남은 절차: campaign 스킬(작전계획)", M → 기존 트랙 A 선언(충분성 게이트 → 브리프 → opord), S → 기존 생략 경로 선언(게이트 → 브리프+구두지시). 기존 트랙 A 본문(A-1~A-4)은 M·S 경로로 명칭만 바꿔 유지 — 생략 4조건(:138-145)이 S 판정 기준으로 §3 에 인용된다.
- [ ] Step 2: 트랙 B(:153-197)를 campaign 위임 절로 교체 — B-1 분해 게이트·B-2 분해 브리프·`<!-- kickoff-breakdown -->` 마커 폐지(작전계획 campaign.md 가 갈음, #1042 결정 5). B-3 재진입 3경로 중 "상위 이슈에 커밋" 경로 폐기(DP = 이슈 = PR 필수), 나머지는 "DP 하위 이슈 킥오프"·"orchestrate 실행"으로 축약해 L 루프에 편입.
- [ ] Step 3: §1(:35) 마커 2종 → 1종(`<!-- kickoff -->` 만), :118 코멘트 상한에서 B-2 언급 제거. :17·:21·:64 의 "트랙" 어휘를 "사이즈"로 정합화.
- [ ] Step 4: 검증 — `grep -n '트랙\|kickoff-breakdown' .claude/skills/kickoff/SKILL.md` 0건 (일반명사 제외 육안), 판정 순서가 설계 세부 §2 와 diff 없음.
- [ ] Step 5: 커밋 (부록 B 커밋 5).

### Task 5: orchestrate — 실행 전용으로 축소

**Files:**
- Modify: `.claude/skills/orchestrate/SKILL.md`

**Interfaces:**
- Consumes: Task 2 스킬명·campaign-progress.md 원장.
- Produces: 실행 전용 스킬 경계 — campaign 평가 모드와 역할 중복 없음.

- [ ] Step 1: §1 분할 확정 → "분할은 campaign.md 7 DP 목록이 정본 — 이 스킬은 그 목록을 받아 실행만 한다. DP 이슈 생성은 L 루프의 issue 단계" 로 교체.
- [ ] Step 2: §3 ledger → campaign-progress.md 원장 참조로 교체 — sub-work 상태(브랜치·base·PR#·머지)는 원장 15항이 담고, dispatch 내부 진행만 세션 장부로. 경로의 `.superpowers/orchestrate/` 를 `.operations/<상위이슈>/campaign-progress.md` 기준으로 재규정.
- [ ] Step 3: §6 종료 → "모든 DP 의 PR 생성 후 campaign 평가 모드로 전달 — 진행 요약 코멘트·잔여 반환은 campaign 소관" 으로 교체.
- [ ] Step 4: description — "kickoff 트랙 B 분해 후" 를 "campaign 작전계획의 DP 실행" 으로, Does NOT trigger 에 "계획·평가(campaign)" 추가.
- [ ] Step 5: 검증 — `grep -n '트랙 B\|superpowers/orchestrate' .claude/skills/orchestrate/SKILL.md` 0건. §2·§4·§5·경계·skill_end 무변경 확인 (`git diff` 육안).
- [ ] Step 6: 커밋 (부록 B 커밋 5 에 합류).

### Task 6: pr·issue·implement·CLAUDE.md 접점

**Files:**
- Modify: `.claude/skills/pr/SKILL.md` · `.claude/skills/issue/SKILL.md` · `.claude/skills/implement/SKILL.md` · `CLAUDE.md`

**Interfaces:**
- Consumes: Task 1 진행 파일 규약, Task 2 campaign 평가 모드, Task 3 opord §6 종결 문언, `report-debrief.md` 항목 번호.
- Produces: 종결 배선 — 이 PR 자신이 첫 적용 대상.

- [ ] Step 1: pr 본문 절에 종결보고 배선 추가 — PR 생성 시 `report-debrief.md` 1(최종상태 대조)·2(산출물·검증)·3(알려진 한계)·10(리뷰어 체크리스트)을 PR 본문 섹션으로, 전문은 이슈 코멘트 `<!-- debrief -->` (4·5·8·9 의 campaign.md 반영은 L 일 때만 — campaign 평가 모드 호출). 기존 "유저 검증 대기" 승계 조항과 중복되지 않게 2 에 흡수.
- [ ] Step 2: pr 에 진행 종결 배선 — PR 생성 시 progress.md 상태 `종결` + 이슈 본문 미러 재조립. 머지 단계에 추가: 이슈 클로즈(한 줄 코멘트 — issue 스킬 규정), 보드 `Done` 이동(기존 "유저가 직접" 문장 교체 — 2026-09-06 교정), 상위 이슈·원장 진행 갱신(L 이면 campaign 평가 모드, 단독 M 이면 상위 진행 코멘트).
- [ ] Step 3: issue `:14` → `상위 이슈: #N / DP-<x.y>` 좌표로 교체 (분해 브리프 리스트업 번호 어휘 제거).
- [ ] Step 4: implement `:27` — "헤더 `상태:` 를 `실행` 으로 갱신하고 … 부록 E 의 상태·커밋 sha 를 갱신한다" 를 progress.md 갱신 + 이슈 미러 재조립로 교체 (opord §6·§8 새 문언과 동일 어휘 — 1-나 위험 완화).
- [ ] Step 5: CLAUDE.md §3 표에 `| 작전계획 작성·평가 (L·XL) | campaign 스킬 |` 행 추가 (opord 행 인접).
- [ ] Step 6: 검증 — `grep -rn '트랙 B\|kickoff-breakdown\|superpowers/orchestrate\|유저가 보드에서 직접' .claude CLAUDE.md` 0건. 진행 파일 어휘(`progress.md`·`<!-- progress -->`)가 opord·implement·pr 세 곳에서 동일한지 육안 대조.
- [ ] Step 7: 이 이슈 자신으로 미러 재조립 실연 — `.operations/1044/progress.md` 작성 → 이슈 본문 = opord.md + progress 블록 (검증 (4)).
- [ ] Step 8: 커밋 (부록 B 커밋 6).

## 부록 B. 커밋 시퀀스 (변경은 사후보고)

1. `[#1044] 작전명령 초안 — campaign 신설과 접점 6과업` — 이 파일 (실행 브랜치 첫 커밋)
2. `[#1044] 위임 권한표를 delegation.md 로 분리하고 진행 층 경로 .operations/ 를 gitignore 에 등재한다` = Task 1
3. `[#1044] campaign 스킬이 L·XL 작전계획 작성·평가 모드·원장을 맡는다` = Task 2
4. `[#1044] opord 진행 상태가 커밋 층에서 나와 .operations/ 진행 파일과 이슈 미러로 옮겨간다` = Task 3
5. `[#1044] kickoff 가 XL/L/M/S 사이즈를 판정하고 orchestrate 는 DP 실행 전용으로 좁아진다` = Task 4+5
6. `[#1044] pr 이 종결보고·이슈 클로즈·보드 이동을 배선하고 issue 링크가 DP 좌표가 된다` = Task 6

## 부록 C. 모델 티어

| 태스크 | 티어 | 근거 |
|---|---|---|
| Task 1 | 하위 (haiku급) | 코멘트 표 이관 + 템플릿 3줄 수정, 경로 확정 |
| Task 2 | 표준 (sonnet급) | 설계 세부 3절 + 템플릿을 한 문서로 통합 — 결정은 확정, 문구 조율만 |
| Task 3~6 | 표준 (sonnet급) | 기존 조항과의 무모순 통합·잔여 grep 판단 |

실행은 이 세션 인라인 (executing-plans) — 설계 맥락이 이 세션에 있고 dispatch 이득이 없다.

## 부록 D. 단편명령 누적

없음
