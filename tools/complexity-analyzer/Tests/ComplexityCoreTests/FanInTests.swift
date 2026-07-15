import Testing
@testable import ComplexityCore

/// stub — 질의를 기록만 한다. 검증은 테스트 케이스가 (testability rules).
final class StubIndexProvider: IndexProviding {
    /// "name@file:line" → usr
    var usrByLocation: [String: String] = [:]
    /// usr → 그 usr을 참조하는 지점들
    var referencesByUSR: [String: [ReferenceSite]] = [:]
    /// usr → 그 심볼을 감싸는 타입 usr
    var enclosingByUSR: [String: String] = [:]
    private(set) var queriedUSRs: [String] = []

    func definitionUSR(named name: String, file: String, line: Int) -> String? {
        usrByLocation["\(name)@\(file):\(line)"]
    }

    func references(toUSR usr: String) -> [ReferenceSite] {
        queriedUSRs.append(usr)
        return referencesByUSR[usr] ?? []
    }

    func enclosingTypeUSR(of usr: String) -> String? {
        enclosingByUSR[usr]
    }
}

@Suite("fan-in per-hop — caller 그래프 BFS")
struct FanInHopTests {

    private func loc(_ name: String, _ file: String, _ line: Int) -> String { "\(name)@\(file):\(line)" }

    @Test("홉0/1/2 참조 수를 caller 그래프로 센다")
    func countsPerHop() {
        let stub = StubIndexProvider()
        stub.usrByLocation[loc("m", "F.swift", 1)] = "m"
        // m 참조 2건, 둘 다 caller c
        stub.referencesByUSR["m"] = [.init(callerUSRs: ["c"]), .init(callerUSRs: ["c"])]
        // c 참조 3건, 모두 caller d
        stub.referencesByUSR["c"] = [.init(callerUSRs: ["d"]), .init(callerUSRs: ["d"]), .init(callerUSRs: ["d"])]
        // d 참조 1건, caller 없음(top-level)
        stub.referencesByUSR["d"] = [.init(callerUSRs: [])]

        let hops = FanIn(index: stub).byHop(name: "m", file: "F.swift", line: 1, maxHop: 2)

        #expect(hops == [2, 3, 1])
    }

    @Test("한 홉에 서로 다른 caller들의 참조가 합산된다")
    func sumsDistinctCallers() {
        let stub = StubIndexProvider()
        stub.usrByLocation[loc("m", "F.swift", 1)] = "m"
        // m 참조 1건이 서로 다른 caller c1·c2를 가리킴
        stub.referencesByUSR["m"] = [.init(callerUSRs: ["c1", "c2"])]
        // c1 참조 2건, c2 참조 3건 → hop1 = 5 (두 frontier USR 합산)
        stub.referencesByUSR["c1"] = [.init(callerUSRs: []), .init(callerUSRs: [])]
        stub.referencesByUSR["c2"] = [.init(callerUSRs: []), .init(callerUSRs: []), .init(callerUSRs: [])]

        #expect(FanIn(index: stub).byHop(name: "m", file: "F.swift", line: 1, maxHop: 2) == [1, 5, 0])
    }

    @Test("caller 없으면 남은 홉은 0으로 채운다")
    func zeroFillsWhenFrontierExhausted() {
        let stub = StubIndexProvider()
        stub.usrByLocation[loc("m", "F.swift", 1)] = "m"
        stub.referencesByUSR["m"] = [.init(callerUSRs: [])]

        #expect(FanIn(index: stub).byHop(name: "m", file: "F.swift", line: 1, maxHop: 2) == [1, 0, 0])
    }

    @Test("caller 사이클은 visited로 차단")
    func cycleGuarded() {
        let stub = StubIndexProvider()
        stub.usrByLocation[loc("m", "F.swift", 1)] = "m"
        stub.referencesByUSR["m"] = [.init(callerUSRs: ["c"])]
        stub.referencesByUSR["c"] = [.init(callerUSRs: ["m"])] // m으로 되돌아감

        #expect(FanIn(index: stub).byHop(name: "m", file: "F.swift", line: 1, maxHop: 2) == [1, 1, 0])
    }

    @Test("USR 못 찾으면 nil")
    func unresolvedIsNil() {
        #expect(FanIn(index: StubIndexProvider()).byHop(name: "nope", file: "F.swift", line: 9, maxHop: 2) == nil)
    }

    @Test("directCount는 hop0만, 미해소는 0")
    func directCountIsHopZero() {
        let stub = StubIndexProvider()
        stub.usrByLocation[loc("T", "F.swift", 3)] = "t"
        stub.referencesByUSR["t"] = [.init(callerUSRs: []), .init(callerUSRs: []), .init(callerUSRs: [])]

        #expect(FanIn(index: stub).directCount(name: "T", file: "F.swift", line: 3) == 3)
        #expect(FanIn(index: stub).directCount(name: "Nope", file: "F.swift", line: 3) == 0)
    }
}
