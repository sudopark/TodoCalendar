import Testing
import Foundation
@testable import ComplexityCore

@Suite("Score 출력 모델")
struct ScoreModelTests {

    @Test("total은 breakdown 값의 합")
    func totalSumsBreakdown() {
        let s = Score(breakdown: ["a": 1.5, "b": 2.0, "c": 0.0])
        #expect(s.total == 3.5)
    }

    @Test("빈 breakdown이면 total 0")
    func emptyBreakdownZero() {
        #expect(Score(breakdown: [:]).total == 0)
    }

    @Test("score 없는 유닛은 JSON에서 생략")
    func nilScoreOmitted() throws {
        let unit = AnalyzedUnit(kind: .method, name: "m", enclosingType: "A", file: "F.swift", line: 1)
        let data = try JSONEncoder().encode(unit)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("score"))
    }

    @Test("score 부착 시 total·breakdown이 JSON에 포함")
    func scoreSerialized() throws {
        var unit = AnalyzedUnit(kind: .type, name: "A", enclosingType: nil, file: "F.swift", line: 1)
        unit.score = Score(breakdown: ["fanOut": 0.7])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(unit), as: UTF8.self)
        #expect(json.contains("\"total\":0.7"))
        #expect(json.contains("\"fanOut\":0.7"))
    }
}
