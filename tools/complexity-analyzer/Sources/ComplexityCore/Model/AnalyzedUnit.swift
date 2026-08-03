import Foundation

/// 단위별 측정값. 페이즈별로 필드가 채워진다 (측정 못 한 축은 nil → JSON에서 생략).
public struct Measurements: Equatable, Sendable, Encodable {
    public var internalComplexity: Int?
    public var fanIn: Int?
    public var cqsViolations: Int?
    public var combineRoleMix: Int?
    public var fanInByHop: [Int]?
    public var rolledUpInternalComplexity: Int?
    public var rolledUpCqsViolations: Int?
    public var rolledUpCombineRoleMix: Int?
    public var publicSurface: Int?
    public var lcom: Int?
    public var internalCoupling: Int?
    public var maxCallChainDepth: Int?
    public var fanOut: Int?
    public var dependencyCycleSize: Int?
    public var collaborationChainDepth: Int?
    public var blastRadiusByHop: [Int]?
    /// 이 타입이 속한 순환(SCC) 안의 참조 타입(class/actor) 수. 순환이 아니면 nil.
    /// 값 타입만인 순환(=데이터 클러스터, 경미)과 참조 타입 낀 순환(=병리)을 가른다.
    public var cycleReferenceTypeCount: Int?

    public init(
        internalComplexity: Int? = nil,
        fanIn: Int? = nil,
        cqsViolations: Int? = nil,
        combineRoleMix: Int? = nil,
        fanInByHop: [Int]? = nil,
        rolledUpInternalComplexity: Int? = nil,
        rolledUpCqsViolations: Int? = nil,
        rolledUpCombineRoleMix: Int? = nil,
        publicSurface: Int? = nil,
        lcom: Int? = nil,
        internalCoupling: Int? = nil,
        maxCallChainDepth: Int? = nil,
        fanOut: Int? = nil,
        dependencyCycleSize: Int? = nil,
        collaborationChainDepth: Int? = nil,
        blastRadiusByHop: [Int]? = nil,
        cycleReferenceTypeCount: Int? = nil
    ) {
        self.internalComplexity = internalComplexity
        self.fanIn = fanIn
        self.cqsViolations = cqsViolations
        self.combineRoleMix = combineRoleMix
        self.fanInByHop = fanInByHop
        self.rolledUpInternalComplexity = rolledUpInternalComplexity
        self.rolledUpCqsViolations = rolledUpCqsViolations
        self.rolledUpCombineRoleMix = rolledUpCombineRoleMix
        self.publicSurface = publicSurface
        self.lcom = lcom
        self.internalCoupling = internalCoupling
        self.maxCallChainDepth = maxCallChainDepth
        self.fanOut = fanOut
        self.dependencyCycleSize = dependencyCycleSize
        self.collaborationChainDepth = collaborationChainDepth
        self.blastRadiusByHop = blastRadiusByHop
        self.cycleReferenceTypeCount = cycleReferenceTypeCount
    }
}

/// 분석 단위 — 페이즈 1은 메소드/타입 레벨.
public struct AnalyzedUnit: Equatable, Sendable, Encodable {
    public enum Kind: String, Sendable, Encodable {
        case method
        case type
    }

    /// 타입 유닛의 선언 종류. 채점 적용성 분기에 쓴다(예: protocol·enum은 LCOM 비적용).
    public enum TypeDeclKind: String, Sendable, Encodable {
        case `struct`, `class`, `enum`, `protocol`, `actor`
    }

    public let kind: Kind
    public let name: String
    public let enclosingType: String?
    public let file: String
    public let line: Int
    /// `.type` 유닛에만 존재. `.method`는 nil.
    public let typeDeclKind: TypeDeclKind?
    public var measurements: Measurements
    public var score: Score?

    public init(
        kind: Kind,
        name: String,
        enclosingType: String?,
        file: String,
        line: Int,
        typeDeclKind: TypeDeclKind? = nil,
        measurements: Measurements = .init(),
        score: Score? = nil
    ) {
        self.kind = kind
        self.name = name
        self.enclosingType = enclosingType
        self.file = file
        self.line = line
        self.typeDeclKind = typeDeclKind
        self.measurements = measurements
        self.score = score
    }

    /// LCOM(구현체 응집도) 측정이 적용되는 타입인가. protocol(구현 없음)·enum(case별 분기라
    /// 구조적으로 낮음)은 비적용 — 과탐 방지. struct/class/actor는 적용.
    var measuresCohesion: Bool {
        switch typeDeclKind {
        case .protocol, .enum: return false
        default: return true
        }
    }
}
