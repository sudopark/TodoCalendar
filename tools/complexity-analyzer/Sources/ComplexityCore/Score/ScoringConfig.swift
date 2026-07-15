import Foundation

/// 스코어링 가중치·threshold·곡선 — 재빌드 없이 `--config <path>` JSON으로 override.
/// 기본값(`default`)은 reasoned default — 실측 캘리브레이션은 후속(값만 갱신).
public struct ScoringConfig: Equatable, Sendable, Codable {

    /// 축적형(크기·개수): min(v/cap,1)*weight.
    public struct AccumulativeParam: Equatable, Sendable, Codable {
        public var cap: Double
        public var weight: Double
        public init(cap: Double, weight: Double) { self.cap = cap; self.weight = weight }
    }

    /// 병리형(오형태): v>threshold ? penalty : 0. ratchet 안 함.
    public struct PathologyParam: Equatable, Sendable, Codable {
        public var threshold: Double
        public var penalty: Double
        public init(threshold: Double, penalty: Double) { self.threshold = threshold; self.penalty = penalty }
    }

    // 메소드
    public var internalComplexity: AccumulativeParam
    public var methodFanIn: AccumulativeParam
    public var cqsViolations: PathologyParam
    public var combineRoleMix: PathologyParam
    // 타입 고유 (연결구조·표면적)
    public var publicSurface: AccumulativeParam
    public var internalCoupling: AccumulativeParam
    public var maxCallChainDepth: AccumulativeParam
    public var lcom: PathologyParam
    // 협업
    public var fanOut: AccumulativeParam
    public var collaborationChainDepth: AccumulativeParam
    public var blastRadius: AccumulativeParam
    public var dependencyCycleSize: PathologyParam
    // 롤업 (× rollupAlpha)
    public var rolledUpInternalComplexity: AccumulativeParam
    public var rolledUpCqsViolations: PathologyParam
    public var rolledUpCombineRoleMix: PathologyParam

    /// 간접 파급 hop 곡선 — 직접(hop0) 싸고 간접 비선형 증폭. fanInByHop·blastRadiusByHop에 적용.
    public var hopWeights: [Double]
    /// 롤업 전가 계수 — 하위 복잡도의 상위 전가율.
    public var rollupAlpha: Double

    public init(
        internalComplexity: AccumulativeParam,
        methodFanIn: AccumulativeParam,
        cqsViolations: PathologyParam,
        combineRoleMix: PathologyParam,
        publicSurface: AccumulativeParam,
        internalCoupling: AccumulativeParam,
        maxCallChainDepth: AccumulativeParam,
        lcom: PathologyParam,
        fanOut: AccumulativeParam,
        collaborationChainDepth: AccumulativeParam,
        blastRadius: AccumulativeParam,
        dependencyCycleSize: PathologyParam,
        rolledUpInternalComplexity: AccumulativeParam,
        rolledUpCqsViolations: PathologyParam,
        rolledUpCombineRoleMix: PathologyParam,
        hopWeights: [Double],
        rollupAlpha: Double
    ) {
        self.internalComplexity = internalComplexity
        self.methodFanIn = methodFanIn
        self.cqsViolations = cqsViolations
        self.combineRoleMix = combineRoleMix
        self.publicSurface = publicSurface
        self.internalCoupling = internalCoupling
        self.maxCallChainDepth = maxCallChainDepth
        self.lcom = lcom
        self.fanOut = fanOut
        self.collaborationChainDepth = collaborationChainDepth
        self.blastRadius = blastRadius
        self.dependencyCycleSize = dependencyCycleSize
        self.rolledUpInternalComplexity = rolledUpInternalComplexity
        self.rolledUpCqsViolations = rolledUpCqsViolations
        self.rolledUpCombineRoleMix = rolledUpCombineRoleMix
        self.hopWeights = hopWeights
        self.rollupAlpha = rollupAlpha
    }

    /// reasoned default — 전형적 Swift 코드 기준 "이 값에서 완전히 나쁨"을 cap으로,
    /// 병리형은 축적형 최대 기여를 압도하는 penalty로. 실측 튜닝 전 출발점.
    public static let `default` = ScoringConfig(
        internalComplexity: .init(cap: 15, weight: 1.0),
        methodFanIn: .init(cap: 60, weight: 0.8),
        cqsViolations: .init(threshold: 0, penalty: 3.0),
        combineRoleMix: .init(threshold: 0, penalty: 2.0),
        publicSurface: .init(cap: 20, weight: 0.5),
        internalCoupling: .init(cap: 30, weight: 0.6),
        maxCallChainDepth: .init(cap: 6, weight: 0.5),
        lcom: .init(threshold: 1, penalty: 4.0),
        fanOut: .init(cap: 20, weight: 0.7),
        collaborationChainDepth: .init(cap: 8, weight: 0.6),
        blastRadius: .init(cap: 60, weight: 0.8),
        dependencyCycleSize: .init(threshold: 1, penalty: 5.0),
        rolledUpInternalComplexity: .init(cap: 80, weight: 1.0),
        rolledUpCqsViolations: .init(threshold: 0, penalty: 3.0),
        rolledUpCombineRoleMix: .init(threshold: 0, penalty: 2.0),
        hopWeights: [1.0, 2.0, 4.0],
        rollupAlpha: 0.5
    )
}
