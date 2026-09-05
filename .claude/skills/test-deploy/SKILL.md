---
name: test-deploy
description: Use when the user wants a test build distributed to Firebase App Distribution — 개발 완료·핫픽스 검증 시점에 특정 브랜치를 테스터에게 내보내는 절차. 피처플래그를 켠 빌드도 배포 브랜치를 따서 내보낸다. Triggers on "테스트 배포 돌려", "이 브랜치 배포해서 확인해볼게", "ddayWidget 켜서 배포해줘". Does NOT trigger on TestFlight 업로드(testflight-deploy 스킬)·앱스토어 심사 제출, 테스트 실행(run-tests 스킬), PR 생성(pr 스킬), 코드 수정(implement 스킬) — 이 스킬의 FeatureFlag.swift 편집은 사전 규정된 리터럴 치환이라 별도 발동 대상이 아니다.
argument-hint: "[flags]"
---

# Test Deploy — TodoCalendar

Fastlane 레인 `ios test_deploy`로 Release 아카이브를 Development 재서명해 Firebase App Distribution `testers` 그룹에 배포한다. GitHub Actions workflow_dispatch(`test_deploy.yml`)로 원격에서 돌리거나, 로컬에서 fastlane 레인을 직접 실행한다.

## 사전 조건

(a) 대상 브랜치가 원격에 push 돼 있을 것 — dispatch는 원격 ref를 기준으로 돈다.
(b) `test_deploy.yml`이 develop에 머지돼 있을 것 — `workflow_dispatch`는 워크플로우 파일이 default 브랜치에 있어야 호출된다. 아직 없으면 `gh workflow run`이 `could not find any workflows named`로 실패한다. 머지 전이라는 뜻이지 스킬 오류가 아니다.
(c) 러너 볼트 `/Users/sudo.park/Desktop/actions/secrets/TodoCalendar`에 실 config 3종(`InfoPlist_Secrets.swift`, `GoogleService-Info.plist`, `secrets.json`)이 있을 것. 최초 1회 셋업:

```bash
mkdir -p /Users/sudo.park/Desktop/actions/secrets/TodoCalendar
chmod 700 /Users/sudo.park/Desktop/actions/secrets/TodoCalendar

SRC=/Users/sudo.park/Documents/codebase/TodoCalendar
DST=/Users/sudo.park/Desktop/actions/secrets/TodoCalendar
cp "$SRC/Tuist/ProjectDescriptionHelpers/InfoPlist_Secrets.swift" "$DST/"
cp "$SRC/TodoCalendarApp/Resources/GoogleService-Info.plist"      "$DST/"
cp "$SRC/TodoCalendarApp/Resources/secrets.json"                  "$DST/"
chmod 600 "$DST"/*
```

## 절차 — 플래그 없이

```bash
# 1. 대상 브랜치 push 확인
git push -u origin "$(git branch --show-current)"

# 2. dispatch — 실패하면 여기서 멈춘다
gh workflow run test_deploy.yml --ref "$(git branch --show-current)"

# 3. 방금 건 run 확보 (목록에 뜨기까지 몇 초 걸린다)
sleep 5
gh run list --workflow test_deploy.yml --branch "$(git branch --show-current)" \
  --event workflow_dispatch --limit 1 --json databaseId,number,status

# 4. 추적
gh run watch <run-id> --exit-status

# 5. 실패 시 로그
gh run view <run-id> --log-failed
```

각 명령이 자족적이다 — Bash 도구는 작업 디렉토리만 유지하고 셸 변수는 블록이 끝나면 사라지므로, 블록을 넘어가는 변수 대입에 기대지 않는다.

2단계가 실패하면 사전 조건 (a)(b)를 다시 확인하고 **중단**한다. 추적으로 넘어가지 않는다.
3단계 결과가 비었거나 `status`가 이미 `completed`면 dispatch가 안 걸린 것이다. 추적하지 말고 중단·보고한다.
3단계 출력의 `databaseId`를 4·5단계의 `<run-id>` 자리에 넣는다. `number`가 빌드번호다.

Firebase 콘솔 링크: `https://console.firebase.google.com/project/todocalendar-1707723626269/appdistribution`

## 절차 — 피처플래그를 켜고

호출 형식은 `/test-deploy ddayWidget`. 요청에 켤 플래그 지정이 있으면 이 경로, 없으면 위 플래그 없음 경로를 탄다.

1. **플래그명 검증** — `Domain/Sources/Utils/FeatureFlag.swift`의 `Flags` enum case와 대조한다. 목록에 없는 이름이 하나라도 있으면 배포하지 않고 중단하고 유효한 case 목록을 보고한다.
   ```bash
   grep -oE "case [a-zA-Z]+" Domain/Sources/Utils/FeatureFlag.swift
   ```
2. **배포 브랜치 생성** — 먼저 `git status --porcelain`이 비어 있는지 확인한다. 비어 있지 않으면 중단하고 사용자에게 알린다 (브랜치를 갈아타면 미커밋 변경이 배포 브랜치로 따라오고 배포 커밋에 딸려 들어간다). 그다음 대상 브랜치가 원격에 push 돼 있는지 확인한다.
   ```bash
   TARGET=$(git branch --show-current)
   git push -u origin "$TARGET"
   git checkout -B "test-deploy/$TARGET" "$TARGET"
   ```
   `-B`라 같은 이름의 배포 브랜치가 이미 있으면 대상 브랜치 기준으로 다시 만든다. 유지하는 것은 배포 브랜치의 **존재**이지 커밋 이력이 아니다 — 매 배포마다 대상 브랜치 기준으로 다시 만들어 강제 갱신한다.
   이후 단계는 이 블록의 셸 변수를 넘겨받지 못한다 — 매 단계가 현재 체크아웃 상태에서 브랜치명을 다시 읽는다.
3. **플래그 활성** — `Domain/Sources/Utils/FeatureFlag.swift`의 아래 한 줄만 고친다. 다른 줄은 건드리지 않는다.
   ```swift
   private var enableFlags: Set<Flags> = []
   ```
   →
   ```swift
   private var enableFlags: Set<Flags> = [.ddayWidget]
   ```
   이 편집은 사전 규정된 리터럴 치환이라 implement 스킬을 별도로 발동하지 않는다.
4. **커밋** — 메시지에 켠 플래그 목록을 반드시 넣는다. 워크플로우가 릴리즈 노트에 브랜치명과 커밋 subject를 싣기 때문에, 이 목록이 곧 Firebase 릴리즈 노트에서 "어떤 플래그가 켜진 빌드인가"를 알려주는 유일한 단서다.
   대상 브랜치명에서 이슈번호를 뽑을 수 있으면(`features/920-...` → `920`) `[#920]`을 쓰고, 못 뽑으면 `[test-deploy]`를 쓴다 (CLAUDE.md §5는 `[#이슈번호]` 형식을 못 박는다 — 이슈번호를 못 뽑을 때만 쓰는 예외).
   ```bash
   git add Domain/Sources/Utils/FeatureFlag.swift
   git commit -m "[#920] 테스트 배포용 피처플래그 활성 — ddayWidget"
   ```
   이 커밋은 이 스킬이 형식을 규정한다 — commit 스킬을 별도로 발동하지 않는다.
5. **push 후 dispatch** — 위 플래그 없음 절차의 3~5단계를 그대로 따르되 ref만 배포 브랜치다. 2단계가 이미 배포 브랜치로 체크아웃을 옮겨놨으므로 현재 체크아웃 상태를 그대로 쓴다. 배포 브랜치는 매번 `-B`로 다시 만들어지므로 두 번째 배포부터 기존 원격 브랜치와 non-fast-forward로 충돌한다 — `--force-with-lease`로 강제 갱신한다.
   ```bash
   git push --force-with-lease -u origin "$(git branch --show-current)"
   gh workflow run test_deploy.yml --ref "$(git branch --show-current)"
   ```
6. **원래 브랜치로 복귀** — dispatch를 건 뒤 바로 돌아온다. 배포 브랜치는 지우지 않는다 — 배포본이 어떤 코드였는지 나중에 추적할 근거다. 현재 브랜치명에서 `test-deploy/` prefix를 벗겨 대상 브랜치명을 역산한다 — 배포 브랜치에 있든 이미 대상 브랜치에 있든 같은 명령으로 동작한다.
   ```bash
   git checkout "$(git branch --show-current | sed 's|^test-deploy/||')"
   ```

어느 단계에서 실패하든 아래 명령으로 돌아온 뒤 보고한다.
```bash
git checkout "$(git branch --show-current | sed 's|^test-deploy/||')"
```

한계: `ddayWidget`은 이 방법으로 완전히 열리지 않는다. `TodoCalendarApp/AppExtensions/Widget/Sources/TodoCalendarWidgetBundle.swift:33-37`가 위젯 갤러리 노출을 컴파일 타임 주석으로 막고 있어(`@WidgetBundleBuilder`가 런타임 `if`를 못 받는다), 플래그를 켜도 일정 상세의 후보 등록 메뉴만 열린다.

## 결과 보고 형식

성공: 빌드번호·브랜치·커밋·켠 플래그 + Firebase 콘솔 링크("절차 — 플래그 없이" 절 참조). 빌드번호는 위 3단계의 `number` 필드다 — `databaseId`는 GitHub 내부 run 식별자일 뿐 테스터가 Firebase에서 보는 빌드번호가 아니다.
실패: 실패 스텝 이름 + 로그 상위 에러.

## 두 실행 경로의 차이

| | dispatch | 로컬 직접 실행 |
|---|---|---|
| 체크아웃 | 원격 ref 기준 fresh (`_work/TodoCalendar/TodoCalendar`) | 현재 워크트리 (미커밋 변경 포함) |
| 실 config | 볼트에서 복사 | 이미 깔린 것 사용 |
| 빌드번호 | run number | `1` 고정 |
| 릴리즈 노트 | 브랜치·커밋·빌드번호 자동 | `"local build"` |

빌드·서명·업로드는 둘 다 같은 fastlane 레인이라 나오는 IPA는 동일하다.

로컬 직접 실행 명령:
```bash
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
TEST_DEPLOY_RELEASE_NOTES="<메모>" bundle exec fastlane ios test_deploy
```

쓸 자리는 둘이다 — (a) 워크플로우가 아직 develop에 없을 때 (b) 커밋하지 않은 로컬 변경을 그대로 확인할 때.

## 종료 기록 — skill_end

배포 결과(성공: 빌드번호·브랜치·플래그 / 실패: 실패 스텝·상위 에러)를 보고한 직후 기록한다 (명령·compliance 규칙은 CLAUDE.md §1). 실패 보고도 절차 완료다.
