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
        maxCallChainDepth: Int? = nil
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
    }
}

/// 분석 단위 — 페이즈 1은 메소드/타입 레벨.
public struct AnalyzedUnit: Equatable, Sendable, Encodable {
    public enum Kind: String, Sendable, Encodable {
        case method
        case type
    }

    public let kind: Kind
    public let name: String
    public let enclosingType: String?
    public let file: String
    public let line: Int
    public var measurements: Measurements

    public init(
        kind: Kind,
        name: String,
        enclosingType: String?,
        file: String,
        line: Int,
        measurements: Measurements = .init()
    ) {
        self.kind = kind
        self.name = name
        self.enclosingType = enclosingType
        self.file = file
        self.line = line
        self.measurements = measurements
    }
}
