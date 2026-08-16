#!/bin/bash
# impact-check.sh stdin 모드 회귀 테스트
cd "$(dirname "$0")" || exit 1
PASS=0; FAIL=0

schemes_for() {
  printf '%b\n' "$1" | bash impact-check.sh --stdin | awk '/^## 테스트 스킴/{getline; print; exit}'
}
tuist_for() {
  printf '%b\n' "$1" | bash impact-check.sh --stdin | awk '/^## tuist generate/{getline; print; exit}'
}
pairs_for() {
  printf '%b\n' "$1" | bash impact-check.sh --stdin | awk '/^## 짝지어진 두 위치/{flag=1; next} flag'
}

assert_eq() { # desc expected actual
  if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  expected: [$2]"; echo "  actual:   [$3]"; fi
}
assert_contains() { # desc pattern actual
  if printf '%s' "$3" | grep -q "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1"; echo "  pattern [$2] not in: [$3]"; fi
}

ALL="AIAgentScene AuthService BillingScenes CalendarScenes Domain EventDetailScene EventListScenes MemberScenes Repository SettingScene TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget"

# --- 스킴 매핑 (pr_test.yml detect-changes 미러) ---
assert_eq "Domain/Sources → 전체" "$ALL" "$(schemes_for 'M\tDomain/Sources/Events/TodoEvent.swift')"
assert_eq "Domain/Tests → Domain만" "Domain" "$(schemes_for 'M\tDomain/Tests/FooTests.swift')"
assert_eq "Repository/Sources → Repo+App+Widget+Share" "Repository TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" "$(schemes_for 'M\tRepository/Sources/Todo/TodoLocalRepositoryImple.swift')"
assert_eq "Repository/Tests → Repository만" "Repository" "$(schemes_for 'M\tRepository/Tests/FooTests.swift')"
assert_eq "Services/AuthService/Sources → AuthService+App" "AuthService TodoCalendarApp" "$(schemes_for 'M\tServices/AuthService/Sources/Foo.swift')"
assert_eq "Services/AuthService/Tests → AuthService만" "AuthService" "$(schemes_for 'M\tServices/AuthService/Tests/FooTests.swift')"
assert_eq "Services/FirstPartyServices → App(테스트 스킴 없음)" "TodoCalendarApp" "$(schemes_for 'M\tServices/FirstPartyServices/Sources/Foo.swift')"
assert_eq "Services/SpeechService → App(테스트 스킴 없음)" "TodoCalendarApp" "$(schemes_for 'M\tServices/SpeechService/Sources/Foo.swift')"
assert_eq "Services/PlaceService → App(테스트 스킴 없음)" "TodoCalendarApp" "$(schemes_for 'M\tServices/PlaceService/Sources/Foo.swift')"
assert_eq "Services/ExternalServices → App(테스트 스킴 없음)" "TodoCalendarApp" "$(schemes_for 'M\tServices/ExternalServices/Sources/Foo.swift')"
assert_eq "Services/StoreKitService → App(테스트 스킴 없음)" "TodoCalendarApp" "$(schemes_for 'M\tServices/StoreKitService/Sources/Foo.swift')"
assert_eq "Services/AdService → App(테스트 스킴 없음)" "TodoCalendarApp" "$(schemes_for 'M\tServices/AdService/Sources/Foo.swift')"
assert_eq "AIAgentScene → 단독" "AIAgentScene" "$(schemes_for 'M\tPresentations/AIAgentScene/Sources/Foo.swift')"
assert_eq "BillingScenes → 단독" "BillingScenes" "$(schemes_for 'M\tPresentations/BillingScenes/Sources/Foo.swift')"
assert_eq "CalendarScenes → +App+Widget" "CalendarScenes TodoCalendarApp TodoCalendarAppWidget" "$(schemes_for 'M\tPresentations/CalendarScenes/Sources/Foo.swift')"
assert_eq "EventDetailScene → +App" "EventDetailScene TodoCalendarApp" "$(schemes_for 'M\tPresentations/EventDetailScene/Sources/Foo.swift')"
assert_eq "CommonPresentation → 전 Presentation+App+Widget+Share" "AIAgentScene BillingScenes CalendarScenes EventDetailScene EventListScenes MemberScenes SettingScene TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" "$(schemes_for 'M\tPresentations/CommonPresentation/Sources/Foo.swift')"
assert_eq "Scenes → 전 Presentation+App (Widget 미의존)" "AIAgentScene BillingScenes CalendarScenes EventDetailScene EventListScenes MemberScenes SettingScene TodoCalendarApp" "$(schemes_for 'M\tPresentations/Scenes/Foo.swift')"
assert_eq "Tuist/ → 전체" "$ALL" "$(schemes_for 'M\tTuist/ProjectDescriptionHelpers/Foo.swift')"
assert_eq "TestDoubles → Domain 제외 전체" "AIAgentScene BillingScenes CalendarScenes EventDetailScene EventListScenes MemberScenes Repository SettingScene TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" "$(schemes_for 'M\tSupports/TestDoubles/Sources/Foo.swift')"
assert_eq "App Sources → App만" "TodoCalendarApp" "$(schemes_for 'M\tTodoCalendarApp/Sources/Root/Foo.swift')"
assert_eq "Widget → Widget만" "TodoCalendarAppWidget" "$(schemes_for 'M\tTodoCalendarApp/AppExtensions/Widget/Foo.swift')"
assert_eq "확장 Base → App+Widget+Share (두 테스트 타겟이 Base를 컴파일)" "TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" "$(schemes_for 'M\tTodoCalendarApp/AppExtensions/Base/Foo.swift')"
assert_eq "확장 Share → App+Share" "TodoCalendarApp TodoCalendarAppShare" "$(schemes_for 'M\tTodoCalendarApp/AppExtensions/Share/Sources/Foo.swift')"
assert_eq "docs만 → 테스트 무관" "(테스트 무관 변경)" "$(schemes_for 'M\tdocs/spec/foo.md')"
assert_eq "복수 영역 합산·중복 제거" "AIAgentScene Repository TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" "$(schemes_for 'M\tRepository/Sources/A.swift\nM\tPresentations/AIAgentScene/Sources/B.swift')"

ALL_WITH_EXTENSIONS="AIAgentScene AuthService BillingScenes CalendarScenes Domain EventDetailScene EventListScenes Extensions MemberScenes Repository SettingScene TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget"
assert_eq "Extensions/Sources → 전체+Extensions" "$ALL_WITH_EXTENSIONS" "$(schemes_for 'M\tSupports/Extensions/Sources/Foo.swift')"
assert_eq "Extensions/Tests → Extensions만" "Extensions" "$(schemes_for 'M\tSupports/Extensions/Tests/FooTests.swift')"

# --- tuist generate 감지 ---
assert_eq "수정만 → 불필요" "불필요" "$(tuist_for 'M\tDomain/Sources/Foo.swift')"
assert_contains "추가 → 필요" "필요" "$(tuist_for 'A\tDomain/Sources/New.swift')"
assert_contains "삭제 → 필요" "필요" "$(tuist_for 'D\tDomain/Sources/Old.swift')"
assert_contains "이동(R) → 필요" "필요" "$(tuist_for 'R100\tDomain/Sources/Old.swift\tDomain/Sources/New.swift')"
assert_eq "비소스 추가(A) → 불필요" "불필요" "$(tuist_for 'A\tdocs/spec/new.md')"
assert_eq "비소스 추가(.claude) → 불필요" "불필요" "$(tuist_for 'A\t.claude/skills/foo/SKILL.md')"
assert_contains "Project.swift 수정(M) → 필요" "필요" "$(tuist_for 'M\tPresentations/SettingScene/Project.swift')"
assert_contains "Tuist helper 수정(M) → 필요" "필요" "$(tuist_for 'M\tTuist/ProjectDescriptionHelpers/Project+Templates.swift')"
assert_contains "Package.swift 수정(M) → 필요" "필요" "$(tuist_for 'M\tPackage.swift')"

# --- 짝 위치 경고 (stdin 모드는 파일 존재 기반 경고만) ---
assert_contains "pr_test.yml 변경 → 3곳 동기화 경고" "impact-check.sh" "$(pairs_for 'M\t.github/workflows/pr_test.yml')"
assert_eq "경고 없음 → 해당 없음" "(해당 없음)" "$(pairs_for 'M\tdocs/foo.md')"

# --- dbVersion 짝 경고 (git 모드 전용 — 임시 repo 를 만들어 --base 로 돌린다) ---
SCRIPT_DIR="$(pwd)"
pairs_in_repo() { # migrateCase(빈문자열이면 미추가) migrationImpleTouched(y/n) → 짝 섹션
  local repo; repo=$(mktemp -d)
  (
    cd "$repo" || exit 1
    git init -q .; git config user.email t@t; git config user.name t
    mkdir -p TodoCalendarApp/Sources Repository/A Repository/B "Repository/Setting/Migration"
    printf '    static let dbVersion: Int32 = 6\n    static let googleCalendarDBVersion: Int32 = 0\n' > TodoCalendarApp/Sources/AppEnvironment.swift
    printf 'struct TableA {\n    static func migrateStatement(for v: Int32) -> String? {\n        switch v {\n        case 0: return nil\n        default: return nil\n        }\n    }\n    var pad = 0\n}\n' > Repository/A/TableA.swift
    cp Repository/A/TableA.swift Repository/B/TableB.swift
    printf 'final class AppDataMigrationImple {\n    var pad = 0\n}\n' > Repository/Setting/Migration/AppDataMigrationImple.swift
    git add -A; git commit -qm base
    sed -i '' 's/dbVersion: Int32 = 6/dbVersion: Int32 = 7/' TodoCalendarApp/Sources/AppEnvironment.swift
    # 무관한 테이블의 migrateStatement 근처를 항상 건드린다 — 컨텍스트 확장 미탐 회귀 감시
    sed -i '' 's/var pad = 0/var pad = 1/' Repository/B/TableB.swift
    [ -n "$1" ] && sed -i '' "s/        case 0: return nil/        case $1: return nil\n        case 0: return nil/" Repository/A/TableA.swift
    [ "$2" = "y" ] && sed -i '' 's/var pad = 0/var pad = 1/' Repository/Setting/Migration/AppDataMigrationImple.swift
    bash "$SCRIPT_DIR/impact-check.sh" --base HEAD | awk '/^## 짝지어진 두 위치/{flag=1; next} flag'
  )
  rm -rf "$repo"
}
assert_contains "dbVersion↑ + case 미추가 → migrateStatement 경고" "case 6 추가가 함께 안 됨" "$(pairs_in_repo '' y)"
assert_contains "dbVersion↑ + 마이그레이션 스텝 미변경 → AppDataMigrationImple 경고" "AppDataMigrationImple" "$(pairs_in_repo 6 n)"
assert_eq "dbVersion↑ + 세 위치 전부 → 경고 없음" "(해당 없음)" "$(pairs_in_repo 6 y)"

echo "---"
echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
