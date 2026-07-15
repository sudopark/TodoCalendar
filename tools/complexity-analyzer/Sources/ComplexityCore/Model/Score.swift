import Foundation

/// 단위별 복잡도 점수 — 종합 총점 + 축별 세분 기여도.
/// 축적형(정규화)·병리형(flag)·롤업 기여가 하나의 breakdown으로 합쳐진다.
public struct Score: Equatable, Sendable, Encodable {
    /// 축 이름 → 가중 기여도. 0 기여 축도 포함(다운스트림 diff 일관성).
    public let breakdown: [String: Double]
    /// breakdown 값의 합.
    public let total: Double

    public init(breakdown: [String: Double]) {
        self.breakdown = breakdown
        self.total = breakdown.values.reduce(0, +)
    }
}
