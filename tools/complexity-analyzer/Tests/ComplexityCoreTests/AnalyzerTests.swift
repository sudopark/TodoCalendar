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
        // realpath로 해소한 sourceRoot를 넘겨, 열거자가 내는 파일 경로 접두와 stub 키·검증 경로를
        // 일치시킨다. (URL.resolvingSymlinksInPath는 /private를 떼는 반대 정규화라 불일치)
        return dir.withCString { cPath in
            guard let resolved = realpath(cPath, nil) else { return dir }
            defer { free(resolved) }
            return String(cString: resolved)
        }
    }

    @Test("타입엔 direct fan-in, 메소드엔 per-hop fan-in이 실린다")
    func measuresAttached() throws {
        let dir = try writeTempDir(["Sample.swift": "struct Sample { func go() { if a { if b {} } } }"])
        let stub = StubIndexProvider()
        // 타입 Sample은 1번째 줄, 메소드 go도 1번째 줄
        stub.usrByLocation["Sample@\(dir)/Sample.swift:1"] = "uSample"
        stub.usrByLocation["go@\(dir)/Sample.swift:1"] = "uGo"
        stub.referencesByUSR["uSample"] = Array(repeating: .init(callerUSRs: []), count: 4)
        stub.referencesByUSR["uGo"] = [.init(callerUSRs: [])]

        let units = try Analyzer(index: stub).analyze(sourceRoot: dir, scope: .whole)

        #expect(units.first { $0.kind == .type }?.measurements.fanIn == 4)
        #expect(units.first { $0.kind == .method }?.measurements.internalComplexity == 3)
        #expect(units.first { $0.kind == .method }?.measurements.fanInByHop == [1, 0, 0])
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
        stub.usrByLocation["S@\(dir)/S.swift:1"] = "u"
        stub.referencesByUSR["u"] = [.init(callerUSRs: []), .init(callerUSRs: [])]
        stub.usrByLocation["f@\(dir)/S.swift:1"] = "uf"
        stub.referencesByUSR["uf"] = [.init(callerUSRs: [])]

        let units = try Analyzer(index: stub).analyze(sourceRoot: dir, scope: .whole)
        let json = try JSONReporter().string(for: units)

        #expect(json.contains("\"fanIn\""))
        #expect(json.contains("\"internalComplexity\""))
        #expect(json.contains("\"fanInByHop\""))
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

    @Test("객체 측정(응집·표면적·롤업)이 JSON에 나온다")
    func objectMeasuresInJSON() throws {
        let dir = try writeTempDir([
            "S.swift": "struct S { var x = 0; public func a() { self.x = 1 }; func b() { print(x) } }"
        ])
        let units = try Analyzer(index: StubIndexProvider()).analyze(sourceRoot: dir, scope: .whole)
        let type = units.first { $0.kind == .type }
        #expect(type?.measurements.lcom == 1)
        #expect(type?.measurements.publicSurface == 1)
        #expect(type?.measurements.rolledUpInternalComplexity == 0)

        let json = try JSONReporter().string(for: units)
        #expect(json.contains("\"lcom\""))
        #expect(json.contains("\"publicSurface\""))
        #expect(json.contains("\"internalCoupling\""))
        #expect(json.contains("\"maxCallChainDepth\""))
        #expect(json.contains("\"rolledUpInternalComplexity\""))
    }

    @Test("cross-file extension 멤버가 원본 타입 롤업·표면적에 합산된다")
    func crossFileExtensionAggregated() throws {
        let dir = try writeTempDir([
            "A.swift": "struct S { var x = 0; public func a() { self.x = 1 } }",
            "B.swift": "extension S { public func b() { if q { if r {} } } }",
        ])
        let units = try Analyzer(index: StubIndexProvider()).analyze(sourceRoot: dir, scope: .whole)
        let s = units.first { $0.kind == .type && $0.name == "S" }?.measurements
        // a: internal 0, b: if{ if{} } = 3 → 다른 파일 extension까지 롤업 3
        #expect(s?.rolledUpInternalComplexity == 3)
        // public a(A.swift) + public b(B.swift) = 2
        #expect(s?.publicSurface == 2)
    }

    @Test("Scope 파싱")
    func scopeParsing() {
        #expect(Scope.parse("whole") == .whole)
        #expect(Scope.parse("file:/a/b.swift") == .file("/a/b.swift"))
        #expect(Scope.parse("type:Foo") == .type("Foo"))
    }
}
