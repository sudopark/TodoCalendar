#!/usr/bin/env python3
"""Project.swift 의존 선언에서 테스트 스킴을 도출한다.

  --all      전체 테스트 스킴을 한 줄에 하나씩 낸다
  --changed  stdin 으로 받은 변경 경로(레포 루트 기준, 한 줄에 하나)가 영향을 주는 테스트 스킴을 낸다
  --root     매니페스트를 읽을 루트 (기본값: 이 스크립트의 레포)

매니페스트에서 못 읽는 의존 형태가 나오면 그 파일 경로를 stderr 에 찍고 exit 1 이다.
"""
import argparse
import os
import re
import sys

# 헬퍼 → 테스트 스킴을 내는지. frameworkWithInterfaceAndTesting·makeAppExtensionTargets 는 withTest 인자가 따로 정한다
HELPERS = {
    "app": True,
    "frameworkWithTest": True,
    "frameworkWithInterfaceAndTesting": True,
    "framework": False,
    "makeAppExtensionTargets": True,
}

# 테스트 타겟에 템플릿이 암묵으로 붙이는 의존 (Project+Templates.swift 테스트 타겟)
IMPLICIT_TEST_DEPENDENCIES = {
    "Supports/UnitTestHelpKit",
    "Supports/TestDoubles",
    "Supports/Common3rdParty",
}

# 확장 타겟이 모듈 의존 없이 앱 프로젝트에서 직접 컴파일·번들하는 경로 (makeAppExtensionTargets)
EXTENSION_SHARED_PATHS = {
    "AppExtensions/Base/**",
    "Sources/AppEnvironment.swift",
    "Sources/DummyFirebaseAuthService.swift",
    "Sources/E2ERunMarker.swift",
    "Sources/NeverRemoveAuthStorage.swift",
    "Sources/AppIntents/OpenAICommandInputIntent.swift",
    "Intents/TodoCalendarWidgetIntents.intentdefinition",
    "Sources/LiveActivity/**",
    "Resources/secrets.json",
    "Resources/GoogleService-Info.plist",
}

FULL_RUN_TRIGGERS = ("Package.swift", "Package.resolved", "Tuist/", "Tuist.swift", "mise.toml", "Workspace.swift")

UNTESTED_DIRS = ("Snapshots/", "E2E/")

DEPENDENCY_LABELS = ("dependencies", "interfaceDependencies", "testingDependencies", "testDependencies")

SYSTEM_DEPENDENCIES = (".external(", ".sdk(", ".xctest")


class ManifestError(Exception):
    pass


# MARK: - Swift 호출식 파싱

def matching_close(text, open_index):
    pairs = {"(": ")", "[": "]"}
    stack = []
    i = open_index
    while i < len(text):
        c = text[i]
        if c == '"':
            i = text.index('"', i + 1)
        elif c in pairs:
            stack.append(pairs[c])
        elif stack and c == stack[-1]:
            stack.pop()
            if not stack:
                return i
        i += 1
    raise ManifestError("괄호가 닫히지 않는다")


def split_top_level(body):
    parts, depth, start, i = [], 0, 0, 0
    while i < len(body):
        c = body[i]
        if c == '"':
            i = body.index('"', i + 1)
        elif c in "([":
            depth += 1
        elif c in ")]":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append(body[start:i].strip())
            start = i + 1
        i += 1
    parts.append(body[start:].strip())
    return [p for p in parts if p]


def call_arguments(text, open_index):
    body = text[open_index + 1:matching_close(text, open_index)]
    arguments = {}
    for part in split_top_level(body):
        label, _, value = part.partition(":")
        arguments[label.strip()] = value.strip()
    return arguments


def string_literal(value):
    m = re.fullmatch(r'"([^"]*)"', value or "")
    return m.group(1) if m else None


def is_single_call(element):
    m = re.match(r"\.\w+\(", element)
    return bool(m) and matching_close(element, m.end() - 1) == len(element) - 1


def array_elements(value):
    value = value.strip()
    if not (value.startswith("[") and value.endswith("]")):
        raise ManifestError(f"배열이 아닌 의존 선언: {value[:40]}")
    return split_top_level(value[1:-1])


# MARK: - 그래프

class Node:
    def __init__(self, key, scheme):
        self.key = key
        self.scheme = scheme
        self.dependencies = set()
        self.raw_dependencies = []
        self.target_names = []


class Graph:
    def __init__(self, root):
        self.root = root
        self.nodes = {}
        self.project_dirs = []
        self.app_projects = {}

    def load(self):
        for project_dir in self.discover_projects():
            path = os.path.join(project_dir, "Project.swift")
            try:
                self.load_manifest(project_dir, path)
            except ManifestError as error:
                raise ManifestError(f"{path}: {error}")
        self.resolve_dependencies()
        return self

    def discover_projects(self):
        with open(os.path.join(self.root, "Workspace.swift")) as f:
            text = f.read()
        m = re.search(r"projects:\s*\[", text)
        globs = [string_literal(e) for e in array_elements(text[m.end() - 1:matching_close(text, m.end() - 1) + 1])]
        found = set()
        for pattern in globs:
            base = pattern[:-3] if pattern.endswith("/**") else pattern
            if not pattern.endswith("/**"):
                if os.path.isfile(os.path.join(self.root, base, "Project.swift")):
                    found.add(base)
                continue
            for current, dirs, files in os.walk(os.path.join(self.root, base)):
                dirs[:] = [d for d in dirs if not d.startswith(".") and not d.endswith(".xcodeproj") and d != "Derived"]
                if "Project.swift" in files:
                    found.add(os.path.relpath(current, self.root))
        return sorted(found)

    def load_manifest(self, project_dir, path):
        with open(os.path.join(self.root, path)) as f:
            text = f.read()
        m = re.search(r"Project\.(\w+)\(", text)
        if not m or m.group(1) not in HELPERS:
            raise ManifestError(f"분류 표에 없는 헬퍼: {m.group(1) if m else '없음'}")
        helper = m.group(1)
        arguments = call_arguments(text, m.end() - 1)
        name = string_literal(arguments.get("name"))
        with_test = HELPERS[helper] and arguments.get("withTest", "true") != "false"
        node = self.add_node(project_dir, name if with_test else None, arguments)
        node.target_names.append(name)
        self.project_dirs.append(project_dir)
        if helper == "app":
            self.load_extensions(project_dir, name, arguments.get("extensionTargets", ""))

    def load_extensions(self, project_dir, app_name, text):
        extensions = {}
        for m in re.finditer(r"Project\.makeAppExtensionTargets\(", text):
            arguments = call_arguments(text, m.end() - 1)
            extension_name = string_literal(arguments.get("extensionName"))
            with_test = arguments.get("withTest", "true") != "false"
            target_name = f"{app_name}{extension_name}"
            node = self.add_node(f"{project_dir}#{extension_name}", target_name if with_test else None, arguments)
            node.target_names.append(target_name)
            extensions[extension_name] = node.key
        self.app_projects[project_dir] = extensions

    def add_node(self, key, scheme, arguments):
        node = Node(key, scheme)
        node.raw_dependencies = [
            (key.split("#")[0], element)
            for label in DEPENDENCY_LABELS if label in arguments
            for element in array_elements(arguments[label])
        ]
        self.nodes[key] = node
        return node

    def resolve_dependencies(self):
        by_target = {name: node.key for node in self.nodes.values() for name in node.target_names}
        for node in self.nodes.values():
            for project_dir, element in node.raw_dependencies:
                node.dependencies |= self.dependency_keys(project_dir, element, by_target)

    def dependency_keys(self, project_dir, element, by_target):
        manifest = f"{project_dir}/Project.swift"
        if element != ".xctest" and not is_single_call(element):
            raise ManifestError(f"{manifest}: 호출 하나가 아닌 의존 원소: {element}")
        if element.startswith(SYSTEM_DEPENDENCIES):
            return set()
        if element.startswith(".project("):
            path = re.search(r'relativeToRoot\("([^"]+)"\)', element)
            if not path or path.group(1) not in self.nodes:
                raise ManifestError(f"{manifest}: 워크스페이스에 없는 프로젝트 의존: {element}")
            return {path.group(1)}
        if element.startswith(".target("):
            name = string_literal(call_arguments(element, element.index("(")).get("name"))
            if name not in by_target:
                raise ManifestError(f"{manifest}: 못 찾은 타겟 의존: {element}")
            return {by_target[name]}
        raise ManifestError(f"{manifest}: 못 읽는 의존 형태: {element}")

    # MARK: - 영향 계산

    def module_closure(self, key):
        seen, stack = set(), [key]
        while stack:
            for dependency in self.nodes[stack.pop()].dependencies:
                if dependency not in seen and dependency in self.nodes:
                    seen.add(dependency)
                    stack.append(dependency)
        return seen

    def test_dependencies(self, key):
        result = self.module_closure(key)
        for test_dependency in IMPLICIT_TEST_DEPENDENCIES & set(self.nodes):
            result |= {test_dependency} | self.module_closure(test_dependency)
        return result

    def tested_nodes(self):
        return [node for node in self.nodes.values() if node.scheme]

    def all_schemes(self):
        return {node.scheme for node in self.tested_nodes()}

    def schemes_affected_by(self, changed_keys):
        return {
            node.scheme for node in self.tested_nodes()
            if node.key in changed_keys or changed_keys & self.test_dependencies(node.key)
        }

    def schemes_for_path(self, path):
        if path.startswith(FULL_RUN_TRIGGERS):
            return self.all_schemes()
        owners = [d for d in self.project_dirs if path.startswith(d + "/")]
        if not owners:
            return set()
        project_dir = max(owners, key=len)
        relative = path[len(project_dir) + 1:]
        if project_dir in self.app_projects:
            return self.schemes_for_app_path(project_dir, relative)
        return self.schemes_for_framework_path(project_dir, relative)

    def schemes_for_framework_path(self, project_dir, relative):
        node = self.nodes[project_dir]
        if relative.startswith(UNTESTED_DIRS):
            return set()
        if relative.startswith("Tests/"):
            return {node.scheme} if node.scheme else set()
        return self.schemes_affected_by({project_dir})

    def schemes_for_app_path(self, project_dir, relative):
        app = self.nodes[project_dir]
        extensions = self.app_projects[project_dir]
        if relative.startswith(UNTESTED_DIRS):
            return set()
        if relative.startswith(f"{app.target_names[0]}Tests/"):
            return {app.scheme}
        if relative == "Project.swift" or any(matches(relative, shared) for shared in EXTENSION_SHARED_PATHS):
            return self.schemes_affected_by({project_dir} | set(extensions.values()))
        m = re.match(r"AppExtensions/([^/]+)/(.*)", relative)
        if m and m.group(1) in extensions:
            extension = self.nodes[extensions[m.group(1)]]
            if m.group(2).startswith("Snapshots/"):
                return set()
            if m.group(2).startswith("Tests/"):
                return {extension.scheme} if extension.scheme else set()
            return self.schemes_affected_by({extension.key})
        return self.schemes_affected_by({project_dir})


def matches(relative, shared):
    if shared.endswith("/**"):
        return relative.startswith(shared[:-2])
    return relative == shared


def main():
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--all", action="store_true")
    mode.add_argument("--changed", action="store_true")
    parser.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    options = parser.parse_args()

    try:
        graph = Graph(options.root).load()
    except ManifestError as error:
        print(f"derive-test-schemes: {error}", file=sys.stderr)
        return 1

    if options.all:
        schemes = graph.all_schemes()
    else:
        paths = [line.strip() for line in sys.stdin if line.strip()]
        schemes = set().union(*(graph.schemes_for_path(p) for p in paths)) if paths else set()

    for scheme in sorted(schemes):
        print(scheme)
    return 0


if __name__ == "__main__":
    sys.exit(main())
