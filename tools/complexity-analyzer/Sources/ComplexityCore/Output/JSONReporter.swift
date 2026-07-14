import Foundation

/// 분석 단위 목록을 JSON으로 직렬화. (페이즈 1: 원시 측정값 나열 — 총점·가중치는 후속)
public struct JSONReporter {

    public init() {}

    public func string(for units: [AnalyzedUnit]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(units)
        return String(decoding: data, as: UTF8.self)
    }
}
