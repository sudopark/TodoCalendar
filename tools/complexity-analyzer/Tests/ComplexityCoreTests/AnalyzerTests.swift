import Testing
import Foundation
@testable import ComplexityCore

@Suite("Analyzer 오케스트레이션 + 리포트")
struct AnalyzerTests {

    private func writeTempDir(_ files: [String: String]) throws -> String {
        let dir = NSTemporaryDirectory() + "cx-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (name, source) in files {
            try source.write(toFile: dir + "/" + name, atomically: true, encoding: .utf8)
        }
        return dir
    }

    @Test("타입엔 fan-in, 메소드엔 내부 복잡도가 실린다")
    func measuresAttached() throws {
        let dir = try writeTempDir(["Sample.swift": "struct Sample { func go() { if a { if b {} } } }"])
        let stub = StubIndexProvider()
        stub.usrsByName["Sample"] = ["u1"]
        stub.refCountByUSR = ["u1": 4]

        let units = try Analyzer(index: stub).analyze(sourceRoot: dir, scope: .whole)

        #expect(units.first { $0.kind == .type }?.measurements.fanIn == 4)
        #expect(units.first { $0.kind == .method }?.measurements.internalComplexity == 3)
    }

    @Test("type scope는 그 타입과 소속 메소드만 남긴다")
    func typeScopeFilters() throws {
        let dir = try writeTempDir(["Two.swift": "struct A { func x() {} }\nstruct B { func y() {} }"])

        let units = try Analyzer(index: StubIndexProvider()).analyze(sourceRoot: dir, scope: .type("A"))

        #expect(units.contains { $0.kind == .type && $0.name == "A" })
        #expect(units.allSatisfy { $0.name == "A" || $0.enclosingType == "A" })
        #expect(!units.contains { $0.name == "B" })
    }

    @Test("JSON 출력에 측정 키가 담긴다")
    func jsonContainsMeasures() throws {
        let dir = try writeTempDir(["S.swift": "struct S { func f() { if a {} } }"])
        let stub = StubIndexProvider()
        stub.usrsByName["S"] = ["u"]
        stub.refCountByUSR = ["u": 2]

        let units = try Analyzer(index: stub).analyze(sourceRoot: dir, scope: .whole)
        let json = try JSONReporter().string(for: units)

        #expect(json.contains("\"fanIn\""))
        #expect(json.contains("\"internalComplexity\""))
    }

    @Test("메소드 단위에 CQS·Combine 측정이 실려 JSON에 나온다")
    func methodMeasuresInJSON() throws {
        let dir = try writeTempDir(["S.swift": "struct S { func f() -> Int { self.x = 1; return x } }"])

        let units = try Analyzer(index: StubIndexProvider()).analyze(sourceRoot: dir, scope: .whole)
        let method = units.first { $0.kind == .method }
        #expect(method?.measurements.cqsViolations == 1)
        #expect(method?.measurements.combineRoleMix == 0)

        let json = try JSONReporter().string(for: units)
        #expect(json.contains("\"cqsViolations\""))
        #expect(json.contains("\"combineRoleMix\""))
    }

    @Test("Scope 파싱")
    func scopeParsing() {
        #expect(Scope.parse("whole") == .whole)
        #expect(Scope.parse("file:/a/b.swift") == .file("/a/b.swift"))
        #expect(Scope.parse("type:Foo") == .type("Foo"))
    }
}
