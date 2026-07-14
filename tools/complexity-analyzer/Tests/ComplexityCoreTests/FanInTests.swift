import Testing
@testable import ComplexityCore

@Suite("fan-in 측정 — 참조 집계")
struct FanInTests {

    @Test("타입의 여러 USR 참조 수를 합산")
    func aggregatesAcrossUSRs() {
        let stub = StubIndexProvider()
        stub.usrsByName["S"] = ["s1", "s2"]
        stub.refCountByUSR = ["s1": 3, "s2": 2]

        let fanIn = FanIn(index: stub)

        #expect(fanIn.count(forTypeNamed: "S") == 5)
        #expect(stub.queriedNames == ["S"])
        #expect(stub.queriedUSRs == ["s1", "s2"])
    }

    @Test("USR 없는 타입은 0")
    func unknownTypeIsZero() {
        #expect(FanIn(index: StubIndexProvider()).count(forTypeNamed: "Nope") == 0)
    }
}

/// stub — 질의를 기록만 한다. 검증은 테스트 케이스가 (testability rules).
final class StubIndexProvider: IndexProviding {
    var usrsByName: [String: [String]] = [:]
    var refCountByUSR: [String: Int] = [:]
    private(set) var queriedNames: [String] = []
    private(set) var queriedUSRs: [String] = []

    func typeUSRs(named name: String) -> [String] {
        queriedNames.append(name)
        return usrsByName[name] ?? []
    }

    func referenceCount(ofUSR usr: String) -> Int {
        queriedUSRs.append(usr)
        return refCountByUSR[usr] ?? 0
    }
}
