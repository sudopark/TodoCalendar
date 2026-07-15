import Testing
@testable import ComplexityCore

@Suite("Scorer — 메소드 채점")
struct ScorerMethodTests {

    /// cap 20/weight 1.0 등 검증이 쉬운 값으로 고정한 config.
    private func config() -> ScoringConfig {
        var c = ScoringConfig.default
        c.internalComplexity = .init(cap: 20, weight: 1.0)
        c.methodFanIn = .init(cap: 100, weight: 1.0)
        c.cqsViolations = .init(threshold: 0, penalty: 3.0)
        c.combineRoleMix = .init(threshold: 0, penalty: 2.0)
        c.hopWeights = [1.0, 2.0, 4.0]
        return c
    }

    @Test("축적형 soft-cap — cap 미만은 비례, cap 이상은 1.0로 포화")
    func accumulativeSoftCap() {
        let s = Scorer(config: config())
        // internalComplexity 10 / cap 20 = 0.5 * weight 1.0
        let half = s.scoreMethod(.init(internalComplexity: 10))
        #expect(half.breakdown["internalComplexity"] == 0.5)
        // 25 > cap 20 → 1.0 포화
        let sat = s.scoreMethod(.init(internalComplexity: 25))
        #expect(sat.breakdown["internalComplexity"] == 1.0)
    }

    @Test("병리형 flag — threshold 초과면 고정 penalty, 이하면 0")
    func pathologyFlag() {
        let s = Scorer(config: config())
        #expect(s.scoreMethod(.init(cqsViolations: 0)).breakdown["cqsViolations"] == 0)
        #expect(s.scoreMethod(.init(cqsViolations: 1)).breakdown["cqsViolations"] == 3.0)
        // 크기 무관 — 5건도 1건과 같은 고정 penalty
        #expect(s.scoreMethod(.init(cqsViolations: 5)).breakdown["cqsViolations"] == 3.0)
    }

    @Test("간접 파급 hop 가중 — 비선형 합산 후 soft-cap")
    func fanInHopWeighted() {
        let s = Scorer(config: config())
        // fanInByHop [10,20,5], hopWeights [1,2,4] → 10+40+20 = 70 / cap 100 = 0.7
        let sc = s.scoreMethod(.init(fanInByHop: [10, 20, 5]))
        #expect(sc.breakdown["fanIn"] == 0.7)
    }

    @Test("nil 측정은 0 기여, total은 축 합")
    func nilIsZeroAndTotalSums() {
        let s = Scorer(config: config())
        let sc = s.scoreMethod(.init(internalComplexity: 10, cqsViolations: 1))
        // 0.5 + 3.0 + 0(roleMix) + 0(fanIn) = 3.5
        #expect(sc.total == 3.5)
    }
}
