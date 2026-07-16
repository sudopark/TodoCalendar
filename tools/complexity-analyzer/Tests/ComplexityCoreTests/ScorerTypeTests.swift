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
        c.lcom = .init(cap: 4, weight: 4.0)  // (lcom-1)/4 * 4
        c.cycleSize = .init(cap: 10, weight: 1.0)
        c.cycleReferenceTypePenalty = 2.0
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

    @Test("LCOM 등급 — 응집(1)은 0, 쪼개질수록 soft-cap으로 커짐")
    func lcomGraded() {
        let s = Scorer(config: config())  // (lcom-1)/cap4 * w4.0
        #expect(s.scoreType(.init(lcom: 1)).breakdown["lcom"] == 0)     // 응집 정상
        #expect(s.scoreType(.init(lcom: 2)).breakdown["lcom"] == 1.0)   // 경미(1/4*4)
        #expect(s.scoreType(.init(lcom: 3)).breakdown["lcom"] == 2.0)   // 2/4*4
        #expect(s.scoreType(.init(lcom: 9)).breakdown["lcom"] == 4.0)   // cap 포화
        #expect(s.scoreType(.init(lcom: nil)).breakdown["lcom"] == 0)   // 미측정(protocol·enum)
    }

    @Test("순환 penalty 등급 — 값 클러스터는 크기만, 참조 타입 낀 순환은 크게")
    func cyclePenaltyGraded() {
        let s = Scorer(config: config())  // cycleSize cap10 w1.0, refPenalty 2.0
        // 순환 아님(size 1) → 0
        #expect(s.scoreType(.init(dependencyCycleSize: 1)).breakdown["cycle"] == 0)
        // 값 타입만 순환(참조 0), size 3 → accum(3/10) = 0.3
        #expect(s.scoreType(.init(dependencyCycleSize: 3, cycleReferenceTypeCount: 0)).breakdown["cycle"] == 0.3)
        // 참조 2개 낀 size 3 → 0.3 + 2*2.0 = 4.3
        #expect(s.scoreType(.init(dependencyCycleSize: 3, cycleReferenceTypeCount: 2)).breakdown["cycle"] == 4.3)
        // 큰 값 클러스터(size 10, 참조 0)도 참조 낀 작은 순환보다 낮다
        let bigValue = s.scoreType(.init(dependencyCycleSize: 10, cycleReferenceTypeCount: 0)).breakdown["cycle"]!
        let smallRef = s.scoreType(.init(dependencyCycleSize: 2, cycleReferenceTypeCount: 1)).breakdown["cycle"]!
        #expect(bigValue < smallRef)
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
        // publicSurface 10(→0.5) + cycle size3 값클러스터(→0.3), 나머지 0 → 0.8
        let sc = Scorer(config: config()).scoreType(.init(publicSurface: 10, dependencyCycleSize: 3, cycleReferenceTypeCount: 0))
        #expect(sc.total == 0.8)
    }

    @Test("scored — kind별 dispatch로 score 부착")
    func scoredDispatchesByKind() {
        let units = [
            AnalyzedUnit(kind: .method, name: "m", enclosingType: "A", file: "F.swift", line: 2,
                         measurements: .init(internalComplexity: 30)),
            AnalyzedUnit(kind: .type, name: "A", enclosingType: nil, file: "F.swift", line: 1,
                         measurements: .init(dependencyCycleSize: 3, cycleReferenceTypeCount: 0)),
        ]
        let scored = Scorer(config: config()).scored(units)
        #expect(scored.first { $0.kind == .method }?.score?.breakdown["internalComplexity"] != nil)
        // 값 클러스터 순환 size3 → cycle 0.3
        #expect(scored.first { $0.kind == .type }?.score?.breakdown["cycle"] == 0.3)
        // 메소드엔 타입 축(cycle)이 없어야
        #expect(scored.first { $0.kind == .method }?.score?.breakdown["cycle"] == nil)
    }
}
