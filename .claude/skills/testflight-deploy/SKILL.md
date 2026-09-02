---
name: testflight-deploy
description: Use when the user wants a build uploaded to TestFlight — 핫픽스·릴리즈 후보를 App Store 서명으로 빌드해 ASC 에 올리는 절차. dSYM 을 Firebase Crashlytics 에 함께 올린다. Triggers on "테플 올려", "TestFlight 배포해줘", "이 브랜치 테플로 빌드해". Does NOT trigger on Firebase App Distribution 테스트 배포(test-deploy 스킬), 심사 제출·릴리즈 발행(#918 후속 단계), 버전업(수동), 테스트 실행(run-tests 스킬).
argument-hint: "<브랜치명> <빌드번호>"
---

# TestFlight Deploy — TodoCalendar

Fastlane 레인 `ios testflight_deploy`로 App Store 서명 빌드를 만들어 App Store Connect TestFlight 에 올린다. dSYM 은 Firebase Crashlytics 에 함께 올린다. 인자 없이 도는 GitHub Actions dispatch 는 없고, 로컬에서 브랜치·빌드번호를 받아 직접 실행한다.

## 사전 조건

1. 환경변수 3종 `ASC_KEY_ID` / `ASC_ISSUER_ID` / `ASC_KEY_CONTENT` — 없으면 `required_env`가 레인을 세운다.
2. `match AppStore` 프로파일 4종이 로컬에 설치돼 있을 것 — `com.sudo.park.TodoCalendarApp` + `.Widget` + `.IntentExtensions` + `.Share`. 확인 명령:
   ```bash
   for f in ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision; do
     security cms -D -i "$f" 2>/dev/null | plutil -extract Name raw -
   done | grep "match AppStore com.sudo.park.TodoCalendarApp"
   ```
3. 러너 볼트 `/Users/sudo.park/Desktop/actions/secrets/TodoCalendar`에 실 config 3종이 있을 것 — `install/install.sh`가 깔아두는 건 더미라 그대로 빌드하면 잘못된 API 호스트·Firebase 프로젝트로 나간다.
4. 빌드번호는 사람이 정한다 — 같은 `CFBundleShortVersionString` 안에서 이미 ASC 에 올라간 값과 겹치면 업로드가 거부된다. App Store Connect > TestFlight 에서 마지막 빌드번호를 확인하고 +1 한다.

## 절차

각 명령 블록은 자족적으로 쓴다 — Bash 도구는 작업 디렉토리만 유지하고 셸 변수는 블록이 끝나면 사라진다.

1. **인자 검증** — 브랜치명·빌드번호 둘 다 있어야 한다. 빌드번호가 정수가 아니면 중단한다. 하나라도 없으면 배포하지 않고 무엇이 빠졌는지 보고한다.

2. **미커밋 변경 가드**
   ```bash
   git status --porcelain
   ```
   출력이 있으면 중단한다. 브랜치를 갈아타면 미커밋 변경이 대상 브랜치로 따라간다. config 3종은 `.gitignore` 대상이라 이 가드에 안 걸린다.

3. **원래 브랜치 기억 + 대상 브랜치 체크아웃**
   ```bash
   git rev-parse --abbrev-ref HEAD   # 출력값을 6단계 복귀에 쓴다
   git fetch origin
   git checkout <브랜치명>
   ```

4. **실 config 배치**
   ```bash
   SECRETS_DIR=/Users/sudo.park/Desktop/actions/secrets/TodoCalendar
   test -d "$SECRETS_DIR"
   cp "$SECRETS_DIR/InfoPlist_Secrets.swift" Tuist/ProjectDescriptionHelpers/InfoPlist_Secrets.swift
   cp "$SECRETS_DIR/GoogleService-Info.plist" TodoCalendarApp/Resources/GoogleService-Info.plist
   cp "$SECRETS_DIR/secrets.json" TodoCalendarApp/Resources/secrets.json
   ```

5. **프로젝트 생성 + 빌드번호 스탬프 + 레인 실행** — 스탬프는 `tuist generate` 뒤에 와야 한다. generate 가 Derived InfoPlist 를 `Project+AppVersion.swift` 값으로 다시 쓰기 때문이다.
   ```bash
   export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
   tuist install
   tuist generate --no-open
   for target in TodoCalendarApp TodoCalendarAppWidget TodoCalendarAppIntentExtensions TodoCalendarAppShare; do
     plutil -replace CFBundleVersion -string "<빌드번호>" \
       "TodoCalendarApp/Derived/InfoPlists/${target}-Info.plist"
   done
   bundle exec fastlane ios testflight_deploy
   ```

6. **원래 브랜치로 복귀** — 성공·실패 무관하게 돌아온다.
   ```bash
   git checkout <3단계에서 기억한 브랜치>
   ```

## 결과 보고 형식

성공: 버전(`Project+AppVersion.swift`의 `appVersion`)·빌드번호·브랜치·커밋 short SHA + ASC TestFlight 링크 `https://appstoreconnect.apple.com/apps` + "ASC 처리에 10~30분 걸리고, 처리가 끝나면 내부 테스터에게 자동으로 간다."

실패: 실패한 단계(빌드 / 업로드 / 심볼) + fastlane 상위 에러. 업로드는 성공했는데 심볼만 실패한 경우는 구분해서 보고한다 — 빌드는 이미 ASC 에 올라갔으므로 같은 빌드번호로 재실행하면 업로드에서 거부된다.

## 한계

- 버전(`CFBundleShortVersionString`)은 브랜치 값 그대로다. 버전업이 필요하면 `Project+AppVersion.swift`를 먼저 고쳐 커밋하고 그 브랜치로 돌린다.
- 심사 제출·외부 테스터 그룹 배포는 이 스킬 밖이다 (ASC 콘솔에서 직접).
- CI 가 없어 로컬 체크아웃을 갈아탄다 — 다른 세션이 같은 워크트리를 쓰고 있으면 충돌한다.

## 종료 기록 — skill_end

배포 결과(성공: 버전·빌드번호·브랜치·커밋 SHA / 실패: 실패 단계·상위 에러)를 보고한 직후 기록한다 (명령·compliance 규칙은 CLAUDE.md §1). 실패 보고도 절차 완료다.
