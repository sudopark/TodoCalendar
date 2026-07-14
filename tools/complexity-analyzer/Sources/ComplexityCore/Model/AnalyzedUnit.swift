import Foundation

/// 단위별 측정값. 페이즈별로 필드가 채워진다 (측정 못 한 축은 nil → JSON에서 생략).
public struct Measurements: Equatable, Sendable, Encodable {
    public var internalComplexity: Int?
    public var fanIn: Int?

    public init(internalComplexity: Int? = nil, fanIn: Int? = nil) {
        self.internalComplexity = internalComplexity
        self.fanIn = fanIn
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
