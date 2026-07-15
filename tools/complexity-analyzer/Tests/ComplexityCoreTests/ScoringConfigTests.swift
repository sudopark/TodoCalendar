import Testing
import Foundation
@testable import ComplexityCore

@Suite("ScoringConfig 외부화·기본값")
struct ScoringConfigTests {

    @Test("기본값은 채점에 필요한 축을 모두 정의")
    func defaultDefinesAxes() {
        let c = ScoringConfig.default
        #expect(c.internalComplexity.cap > 0)
        #expect(c.dependencyCycleSize.penalty > 0)
        #expect(c.hopWeights.count == 3)
        #expect(c.rollupAlpha > 0)
    }

    @Test("hop 가중은 비선형 증가 — 간접 홉이 더 비쌈")
    func hopWeightsNonLinearIncreasing() {
        let w = ScoringConfig.default.hopWeights
        #expect(w[0] < w[1])
        #expect(w[1] < w[2])
    }

    @Test("병리형은 축적형보다 큰 가중 — cycle penalty > publicSurface weight")
    func pathologyOutweighsAccumulative() {
        let c = ScoringConfig.default
        #expect(c.dependencyCycleSize.penalty > c.publicSurface.weight)
    }

    @Test("JSON encode→decode 라운드트립이 기본값과 동일 (--config 계약)")
    func jsonRoundTrips() throws {
        let original = ScoringConfig.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScoringConfig.self, from: data)
        #expect(decoded == original)
    }
}
