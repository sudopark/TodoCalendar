import Foundation

/// raw Measurements를 config 가중치로 점수화하는 per-unit pure 함수.
/// 축적형=soft-cap 정규화, 병리형=고정 flag, 롤업=rolledUp 축에 α.
public struct Scorer {

    private let config: ScoringConfig

    public init(config: ScoringConfig = .default) {
        self.config = config
    }

    // MARK: - 메소드

    public func scoreMethod(_ m: Measurements) -> Score {
        Score(breakdown: [
            "internalComplexity": accum(Double(m.internalComplexity ?? 0), config.internalComplexity),
            "fanIn": accum(hopWeighted(m.fanInByHop), config.methodFanIn),
            "cqsViolations": flag(m.cqsViolations, config.cqsViolations),
            "combineRoleMix": flag(m.combineRoleMix, config.combineRoleMix),
        ])
    }

    // MARK: - 타입

    public func scoreType(_ m: Measurements) -> Score {
        let a = config.rollupAlpha
        return Score(breakdown: [
            // 롤업 (× α) — 이슈 공식 α·Σ Score(메소드)의 실현
            "rollup.internalComplexity": a * accum(Double(m.rolledUpInternalComplexity ?? 0), config.rolledUpInternalComplexity),
            "rollup.cqsViolations": a * flag(m.rolledUpCqsViolations, config.rolledUpCqsViolations),
            "rollup.combineRoleMix": a * flag(m.rolledUpCombineRoleMix, config.rolledUpCombineRoleMix),
            // 객체 고유 (연결구조·표면적)
            "publicSurface": accum(Double(m.publicSurface ?? 0), config.publicSurface),
            "internalCoupling": accum(Double(m.internalCoupling ?? 0), config.internalCoupling),
            "maxCallChainDepth": accum(Double(m.maxCallChainDepth ?? 0), config.maxCallChainDepth),
            "lcom": flag(m.lcom, config.lcom),
            // 협업
            "fanOut": accum(Double(m.fanOut ?? 0), config.fanOut),
            "collaborationChainDepth": accum(Double(m.collaborationChainDepth ?? 0), config.collaborationChainDepth),
            "blastRadius": accum(hopWeighted(m.blastRadiusByHop), config.blastRadius),
            "dependencyCycleSize": flag(m.dependencyCycleSize, config.dependencyCycleSize),
        ])
    }

    // MARK: - dispatch

    /// 유닛별 kind에 맞춰 score를 부착한다. per-unit pure — 유닛 간 참조 없음.
    public func scored(_ units: [AnalyzedUnit]) -> [AnalyzedUnit] {
        units.map { unit in
            var scored = unit
            switch unit.kind {
            case .method: scored.score = scoreMethod(unit.measurements)
            case .type: scored.score = scoreType(unit.measurements)
            }
            return scored
        }
    }

    // MARK: - 채점 헬퍼

    /// 축적형: cap으로 [0,1] 정규화 후 가중. cap ≤ 0이면 0.
    private func accum(_ value: Double, _ p: ScoringConfig.AccumulativeParam) -> Double {
        guard p.cap > 0 else { return 0 }
        return min(value / p.cap, 1.0) * p.weight
    }

    /// 병리형: threshold 초과면 고정 penalty. ratchet 안 함(크기 무관).
    private func flag(_ value: Int?, _ p: ScoringConfig.PathologyParam) -> Double {
        Double(value ?? 0) > p.threshold ? p.penalty : 0
    }

    /// 간접 파급: hop별 비선형 가중 합. 짧은 배열까지만 zip.
    private func hopWeighted(_ hops: [Int]?) -> Double {
        guard let hops else { return 0 }
        return zip(hops, config.hopWeights).reduce(0) { $0 + Double($1.0) * $1.1 }
    }
}
