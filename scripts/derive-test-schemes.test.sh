#!/bin/bash
# derive-test-schemes.py 회귀 — 스킴 목록·변경 경로 매핑과, 스크립트 안 데이터 표가 Tuist 템플릿과 맞는지 본다.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
SCRIPT="$ROOT/scripts/derive-test-schemes.py"
TEMPLATE="$ROOT/Tuist/ProjectDescriptionHelpers/Project+Templates.swift"
FIXTURE="$(mktemp -d)"
FIXTURE2="$(mktemp -d)"
trap 'rm -rf "$FIXTURE" "$FIXTURE2"' EXIT

check() { # desc status [실제값]
  if [ "$2" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL: $1 ${3:+(실제 $3)}"; fi
}

changed() { # root paths...
  local root="$1"; shift
  printf '%s\n' "$@" | python3 "$SCRIPT" --root "$root" --changed | tr '\n' ' ' | sed 's/ $//'
}

ALL=$(python3 "$SCRIPT" --all | tr '\n' ' ' | sed 's/ $//')

# --- 전체 목록 ---
echo " $ALL " | grep -q " SceneInfra " && echo " $ALL " | grep -q " UnitTestHelpKit "
check "all_includes_SceneInfra_and_UnitTestHelpKit" $? "$ALL"

# --- 실제 매니페스트 매핑 ---
out=$(changed "$ROOT" Presentations/AIAgentScene/Sources/x.swift)
[ "$out" = "AIAgentScene TodoCalendarApp" ]; check "AIAgentScene_source_selects_app" $? "$out"
out=$(changed "$ROOT" Presentations/BillingScenes/Sources/x.swift)
[ "$out" = "BillingScenes TodoCalendarApp" ]; check "BillingScenes_source_selects_app" $? "$out"
out=$(changed "$ROOT" Supports/TestDoubles/Sources/x.swift)
echo " $out " | grep -q " CalendarScenes " && ! echo " $out " | grep -q " EventDomain "
check "TestDoubles_source_selects_only_presentation_tests" $? "$out"
for p in Sources/AppEnvironment.swift Resources/secrets.json Project.swift; do
  out=$(changed "$ROOT" "TodoCalendarApp/$p")
  [ "$out" = "TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" ]; check "app_$p selects_app_widget_share" $? "$out"
done
out=$(changed "$ROOT" Domain/CalendarDomain/Sources/x.swift)
echo " $out " | grep -q " CalendarDomain " && ! echo " $out " | grep -q " SettingScene "
check "subdomain_impl_change_skips_interface_only_consumers" $? "$out"
out=$(changed "$ROOT" Domain/CalendarDomain/Interface/x.swift)
echo " $out " | grep -q " SettingScene "; check "subdomain_interface_change_reaches_interface_consumers" $? "$out"
out=$(changed "$ROOT" Services/StoreKitService/Sources/x.swift)
[ "$out" = "TodoCalendarApp" ]; check "untested_framework_source_selects_dependent_app" $? "$out"
out=$(changed "$ROOT" Domain/EventDomain/Tests/x.swift)
[ "$out" = "EventDomain" ]; check "subdomain_tests_select_only_that_subdomain" $? "$out"
out=$(changed "$ROOT" TodoCalendarApp/AppExtensions/Base/x.swift)
[ "$out" = "TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" ]; check "Base_source_selects_app_widget_share" $? "$out"
out=$(changed "$ROOT" TodoCalendarApp/Sources/LiveActivity/x.swift)
[ "$out" = "TodoCalendarApp TodoCalendarAppShare TodoCalendarAppWidget" ]; check "LiveActivity_source_selects_app_widget_share" $? "$out"
out=$(changed "$ROOT" TodoCalendarApp/TodoCalendarAppTests/x.swift)
[ "$out" = "TodoCalendarApp" ]; check "App_tests_select_only_app" $? "$out"
out=$(changed "$ROOT" TodoCalendarApp/AppExtensions/Widget/Tests/x.swift)
[ "$out" = "TodoCalendarAppWidget" ]; check "Widget_tests_select_only_widget" $? "$out"
out=$(changed "$ROOT" TodoCalendarApp/AppExtensions/Widget/Sources/x.swift)
[ "$out" = "TodoCalendarApp TodoCalendarAppWidget" ]; check "Widget_source_selects_widget_and_embedding_app" $? "$out"
out=$(changed "$ROOT" TodoCalendarApp/AppExtensions/IntentExtensions/Sources/x.swift)
[ "$out" = "TodoCalendarApp" ]; check "untested_extension_source_selects_app" $? "$out"
out=$(changed "$ROOT" Tuist/ProjectDescriptionHelpers/Project+Templates.swift)
[ "$out" = "$ALL" ]; check "Tuist_change_selects_all" $? "$out"
out=$(changed "$ROOT" Workspace.swift)
[ "$out" = "$ALL" ]; check "Workspace_change_selects_all" $? "$out"
for p in Package.swift Package.resolved Tuist.swift mise.toml; do
  out=$(changed "$ROOT" "$p")
  [ "$out" = "$ALL" ]; check "${p}_change_selects_all" $? "$out"
done
out=$(changed "$ROOT" docs/x.md scripts/x.sh .github/workflows/pr_test.yml)
[ -z "$out" ]; check "docs_change_selects_none" $? "$out"
out=$(changed "$ROOT" Presentations/CalendarScenes/Snapshots/x.swift TodoCalendarApp/E2E/x.swift TodoCalendarApp/AppExtensions/Widget/Snapshots/x.swift)
[ -z "$out" ]; check "snapshots_and_e2e_select_none" $? "$out"
out=$(printf '' | python3 "$SCRIPT" --changed); status=$?
[ -z "$out" ] && [ $status -eq 0 ]; check "empty_input_selects_none" $? "$out/$status"

# --- 픽스처 매니페스트 ---
mkdir -p "$FIXTURE/Mods/A/BB" "$FIXTURE/Mods/C"
cat > "$FIXTURE/Workspace.swift" <<'SWIFT'
let workspace = Workspace(name: "Fixture", projects: [ "Mods/**" ])
SWIFT
cat > "$FIXTURE/Mods/A/Project.swift" <<'SWIFT'
let project = Project.frameworkWithTest(name: "A", destinations: [.iPhone], iOSTargetVersion: "17.0")
SWIFT
cat > "$FIXTURE/Mods/A/BB/Project.swift" <<'SWIFT'
let project = Project.frameworkWithTest(
    name: "BB",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    dependencies: [
        .project(
            target: "A",
            path: .relativeToRoot("Mods/A")
        ),
        .external(name: "Prelude")
    ]
)
SWIFT
out=$(changed "$FIXTURE" Mods/A/BB/Sources/x.swift)
[ "$out" = "BB" ]; check "nested_project_owns_by_longest_prefix" $? "$out"
out=$(changed "$FIXTURE" Mods/A/Sources/x.swift)
[ "$out" = "A BB" ]; check "nested_parent_change_reaches_dependent" $? "$out"

cat > "$FIXTURE/Mods/C/Project.swift" <<'SWIFT'
let project = Project.frameworkWithInterfaceAndTesting(
    name: "C",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [.project(target: "A", path: .relativeToRoot("Mods/A"))],
    testingDependencies: [.project(target: "BB", path: .relativeToRoot("Mods/A/BB"))]
)
SWIFT
out=$(python3 "$SCRIPT" --root "$FIXTURE" --all | tr '\n' ' ' | sed 's/ $//')
[ "$out" = "A BB C" ]; check "new_module_detected_without_registration" $? "$out"
out=$(changed "$FIXTURE" Mods/A/Sources/x.swift)
[ "$out" = "A BB C" ]; check "interface_dependency_reaches_dependent" $? "$out"
out=$(changed "$FIXTURE" Mods/A/BB/Sources/x.swift)
[ "$out" = "BB C" ]; check "testing_dependency_reaches_dependent" $? "$out"

mkdir -p "$FIXTURE/Mods/E" "$FIXTURE/Mods/F" "$FIXTURE/Mods/G"
cat > "$FIXTURE/Mods/E/Project.swift" <<'SWIFT'
let project = Project.frameworkWithTest(name: "E", destinations: [.iPhone], iOSTargetVersion: "17.0",
    testDependencies: [.project(target: "BB", path: .relativeToRoot("Mods/A/BB"))])
SWIFT
out=$(changed "$FIXTURE" Mods/A/BB/Sources/x.swift)
[ "$out" = "BB C E" ]; check "test_dependency_reaches_dependent" $? "$out"

cat > "$FIXTURE/Mods/F/Project.swift" <<'SWIFT'
let project = Project.frameworkWithInterfaceAndTesting(
    name: "F",
    destinations: [.iPhone],
    iOSTargetVersion: "17.0",
    interfaceDependencies: [.project(target: "A", path: .relativeToRoot("Mods/A"))]
)
SWIFT
cat > "$FIXTURE/Mods/G/Project.swift" <<'SWIFT'
let project = Project.frameworkWithTest(name: "G", destinations: [.iPhone], iOSTargetVersion: "17.0",
    dependencies: [.project(target: "FInterface", path: .relativeToRoot("Mods/F"))])
SWIFT
all=$(python3 "$SCRIPT" --root "$FIXTURE" --all | tr '\n' ' ' | sed 's/ $//')
out=$(changed "$FIXTURE" Mods/F/Interface/x.swift)
[ "$all" = "A BB C E F G" ] && [ "$out" = "F G" ]; check "interface_change_reaches_interface_consumer" $? "$all / $out"
out=$(changed "$FIXTURE" Mods/F/Sources/x.swift)
[ "$out" = "F" ]; check "implementation_change_skips_interface_consumer" $? "$out"

mkdir -p "$FIXTURE/Mods/D"
cat > "$FIXTURE/Mods/D/Project.swift" <<'SWIFT'
let project = Project.frameworkWithTest(name: "D", destinations: [.iPhone], iOSTargetVersion: "17.0",
    dependencies: [.package(product: "X")])
SWIFT
err=$(printf 'Mods/A/Sources/x.swift\n' | python3 "$SCRIPT" --root "$FIXTURE" --changed 2>&1 >/dev/null); status=$?
[ $status -eq 1 ] && echo "$err" | grep -q "Mods/D/Project.swift"; check "unparsable_dependency_fails_loudly" $? "$status $err"

mkdir -p "$FIXTURE2/Mods/A" "$FIXTURE2/Mods/B" "$FIXTURE2/Mods/C" "$FIXTURE2/Lone"
cat > "$FIXTURE2/Workspace.swift" <<'SWIFT'
let workspace = Workspace(name: "Fixture", projects: [ "Mods/**", "Lone" ])
SWIFT
dep() { echo ".project(target: \"$1\", path: .relativeToRoot(\"Mods/$1\"))"; }
write_module() { # 디렉터리 이름 의존배열
  echo "let project = Project.frameworkWithTest(name: \"$2\", destinations: [.iPhone], iOSTargetVersion: \"17.0\", dependencies: $3)" > "$FIXTURE2/$1/Project.swift"
}
write_module Mods/A A "[]"; write_module Mods/B B "[$(dep A)]"; write_module Mods/C C "[$(dep B)]"; write_module Lone Lone "[]"
out=$(changed "$FIXTURE2" Mods/A/Sources/x.swift)
[ "$out" = "A B C" ]; check "transitive_dependent_selected" $? "$out"
out=$(python3 "$SCRIPT" --root "$FIXTURE2" --all | tr '\n' ' ' | sed 's/ $//')
[ "$out" = "A B C Lone" ]; check "literal_workspace_entry_detected" $? "$out"

mkdir -p "$FIXTURE2/Mods/M" "$FIXTURE2/Mods/N"
echo "let project = Project.framework(name: \"M\", destinations: [.iPhone], iOSTargetVersion: \"17.0\", dependencies: [$(dep A)])" > "$FIXTURE2/Mods/M/Project.swift"
write_module Mods/N N "[$(dep M)]"
out=$(python3 "$SCRIPT" --root "$FIXTURE2" --all | tr '\n' ' ' | sed 's/ $//')
[ "$out" = "A B C Lone N" ]; check "untested_framework_has_no_scheme" $? "$out"
out=$(changed "$FIXTURE2" Mods/M/Sources/x.swift)
[ "$out" = "N" ]; check "untested_framework_change_selects_dependent" $? "$out"
out=$(changed "$FIXTURE2" Mods/A/Sources/x.swift)
[ "$out" = "A B C N" ]; check "dependent_reached_through_untested_framework" $? "$out"

write_module Mods/C C "[$(dep A)] + [$(dep B)]"
err=$(printf 'Mods/B/Sources/x.swift\n' | python3 "$SCRIPT" --root "$FIXTURE2" --changed 2>&1 >/dev/null); status=$?
[ $status -eq 1 ] && echo "$err" | grep -q "Mods/C/Project.swift"; check "concatenated_dependency_arrays_fail_loudly" $? "$status $err"

write_module Mods/C C "[$(dep Missing)]"
err=$(printf 'Mods/B/Sources/x.swift\n' | python3 "$SCRIPT" --root "$FIXTURE2" --changed 2>&1 >/dev/null); status=$?
[ $status -eq 1 ] && echo "$err" | grep -q "Mods/C/Project.swift"; check "dependency_outside_workspace_fails_loudly" $? "$status $err"

# --- 데이터 표 ↔ Tuist 템플릿 짝 ---
tables() { # 표 이름
  python3 - "$SCRIPT" "$1" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("derive", sys.argv[1])
mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
print("\n".join(sorted(getattr(mod, sys.argv[2]))))
PY
}
template_extension_globs() {
  awk '/func makeAppExtensionTargets/{f=1} f&&/let target = Target.target/{exit} f' "$TEMPLATE" \
    | grep -oE '"[^"]+"' | tr -d '"' | grep -v '\\(' | sort
  awk '/func makeAppExtensionTargets/{f=1} f&&/resources: \[/{r=1} f&&r&&/\]/{exit} f&&r' "$TEMPLATE" \
    | grep -oE '"[^"]+"' | tr -d '"' | grep -v '\\(' | sort
}
diff <(template_extension_globs | sort -u) <(tables EXTENSION_SHARED_PATHS) >/dev/null
check "extension_table_matches_template_globs" $? "$(diff <(template_extension_globs | sort -u) <(tables EXTENSION_SHARED_PATHS) | tr '\n' ' ')"

template_helpers=$(grep -oE 'public static func [A-Za-z]+' "$TEMPLATE" | awk '{print $4}' | sort -u)
diff <(echo "$template_helpers") <(tables HELPERS) >/dev/null
check "every_public_helper_is_classified" $? "$(diff <(echo "$template_helpers") <(tables HELPERS) | tr '\n' ' ')"

template_test_deps=$(awk '/func (makeUnitTestsTarget|makeAppTargets|makeAppExtensionTargets)\(/{f=1} /func (makeSnapshotsTarget|makeE2ETarget|makeFrameworkTargets|makeFrameworkTargetsWithTest|makeStaticFrameworkTarget)\(/{f=0} /snapshotTests \{/{f=0} f' "$TEMPLATE" \
  | grep -oE 'relativeToRoot\("[^"]+"\)' | sed -E 's/relativeToRoot\("(.*)"\)/\1/' | sort -u)
diff <(echo "$template_test_deps") <(tables IMPLICIT_TEST_DEPENDENCIES) >/dev/null
check "implicit_test_deps_match_template" $? "$(diff <(echo "$template_test_deps") <(tables IMPLICIT_TEST_DEPENDENCIES) | tr '\n' ' ')"

echo "PASS: $PASS / FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
