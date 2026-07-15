import Testing
import Foundation
@testable import ComplexityCore

@Suite("스코어링 배선 — Analyzer 적용")
struct ScorerWiringTests {

    @Test("analyze 결과 유닛에 score가 부착되고 raw 측정도 보존")
    func analyzeAttachesScore() throws {
        // 최소 소스 하나를 스캔 — 실 index 없이도 SyntaxScanner 측정은 돈다.
        let dir = NSTemporaryDirectory() + "cx-score-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        let file = dir + "/Sample.swift"
        try "struct Sample { func run() { if true { print(1) } } }".write(toFile: file, atomically: true, encoding: .utf8)

        let units = try Analyzer(index: EmptyIndex()).analyze(sourceRoot: dir, scope: .whole)
        #expect(!units.isEmpty)
        // 모든 유닛에 score 부착
        #expect(units.allSatisfy { $0.score != nil })
        // raw 측정도 살아있음 (타입은 표면적 등)
        let type = units.first { $0.kind == .type }
        #expect(type?.measurements.publicSurface != nil)
    }

    @Test("JSON 출력에 score.total이 포함")
    func jsonIncludesScore() throws {
        let unit = AnalyzedUnit(kind: .type, name: "A", enclosingType: nil, file: "F.swift", line: 1,
                                measurements: .init(publicSurface: 4),
                                score: Scorer().scoreType(.init(publicSurface: 4)))
        let json = try JSONReporter().string(for: [unit])
        #expect(json.contains("\"total\""))
        #expect(json.contains("\"publicSurface\""))
    }
}

/// 실 index 없이 배선만 검증 — 참조 질의는 전부 빈 결과.
private struct EmptyIndex: IndexProviding {
    func definitionUSR(named name: String, file: String, line: Int) -> String? { nil }
    func references(toUSR usr: String) -> [ReferenceSite] { [] }
    func enclosingTypeUSR(of usr: String) -> String? { nil }
}
