import Testing
@testable import ComplexityCore

@Suite("Scorer — 타입 채점·롤업")
struct ScorerTypeTests {

    private func config() -> ScoringConfig {
        var c = ScoringConfig.default
        c.publicSurface = .init(cap: 20, weight: 1.0)
        c.fanOut = .init(cap: 10, weight: 1.0)
        c.blastRadius = .init(cap: 100, weight: 1.0)
        c.collaborationChainDepth = .init(cap: 8, weight: 1.0)
        c.internalCoupling = .init(cap: 30, weight: 1.0)
        c.maxCallChainDepth = .init(cap: 6, weight: 1.0)
        c.lcom = .init(threshold: 1, penalty: 4.0)
        c.dependencyCycleSize = .init(threshold: 1, penalty: 5.0)
        c.rolledUpInternalComplexity = .init(cap: 100, weight: 1.0)
        c.rolledUpCqsViolations = .init(threshold: 0, penalty: 3.0)
        c.rolledUpCombineRoleMix = .init(threshold: 0, penalty: 2.0)
        c.hopWeights = [1.0, 2.0, 4.0]
        c.rollupAlpha = 0.5
        return c
    }

    @Test("객체 고유 축적형 — 표면적 soft-cap")
    func publicSurfaceScored() {
        let sc = Scorer(config: config()).scoreType(.init(publicSurface: 10))
        #expect(sc.breakdown["publicSurface"] == 0.5)  // 10/20
    }

    @Test("병리형 flag — LCOM4>1·cycle>1 고정 penalty")
    func typePathologyFlags() {
        let s = Scorer(config: config())
        // lcom 1 = 응집(정상) → 0, 2 = 끊김 → 4.0
        #expect(s.scoreType(.init(lcom: 1)).breakdown["lcom"] == 0)
        #expect(s.scoreType(.init(lcom: 2)).breakdown["lcom"] == 4.0)
        // cycleSize 1 = 무순환 → 0, 3 = 순환 → 5.0
        #expect(s.scoreType(.init(dependencyCycleSize: 1)).breakdown["dependencyCycleSize"] == 0)
        #expect(s.scoreType(.init(dependencyCycleSize: 3)).breakdown["dependencyCycleSize"] == 5.0)
    }

    @Test("협업 blast — hop 비선형 가중")
    func blastHopWeighted() {
        // blastRadiusByHop [10,20,5], hopWeights [1,2,4] → 70 / cap 100 = 0.7
        let sc = Scorer(config: config()).scoreType(.init(blastRadiusByHop: [10, 20, 5]))
        #expect(sc.breakdown["blastRadius"] == 0.7)
    }

    @Test("롤업 — rolledUp 축에 α 전가")
    func rollupScaledByAlpha() {
        let s = Scorer(config: config())
        // rolledUpInternalComplexity 100 / cap 100 = 1.0 * weight 1.0 * α 0.5 = 0.5
        let sc = s.scoreType(.init(rolledUpInternalComplexity: 100))
        #expect(sc.breakdown["rollup.internalComplexity"] == 0.5)
        // rolledUpCqsViolations 2 > 0 → penalty 3.0 * α 0.5 = 1.5
        let sc2 = s.scoreType(.init(rolledUpCqsViolations: 2))
        #expect(sc2.breakdown["rollup.cqsViolations"] == 1.5)
    }

    @Test("total은 롤업·고유·협업 축 전부 합")
    func totalSumsAllBlocks() {
        // publicSurface 10(→0.5) + cycle 3(→5.0), 나머지 0 → 5.5
        let sc = Scorer(config: config()).scoreType(.init(publicSurface: 10, dependencyCycleSize: 3))
        #expect(sc.total == 5.5)
    }

    @Test("scored — kind별 dispatch로 score 부착")
    func scoredDispatchesByKind() {
        let units = [
            AnalyzedUnit(kind: .method, name: "m", enclosingType: "A", file: "F.swift", line: 2,
                         measurements: .init(internalComplexity: 30)),
            AnalyzedUnit(kind: .type, name: "A", enclosingType: nil, file: "F.swift", line: 1,
                         measurements: .init(dependencyCycleSize: 3)),
        ]
        let scored = Scorer(config: config()).scored(units)
        #expect(scored.first { $0.kind == .method }?.score?.breakdown["internalComplexity"] != nil)
        #expect(scored.first { $0.kind == .type }?.score?.breakdown["dependencyCycleSize"] == 5.0)
        // 메소드엔 타입 축(dependencyCycleSize)이 없어야
        #expect(scored.first { $0.kind == .method }?.score?.breakdown["dependencyCycleSize"] == nil)
    }
}
