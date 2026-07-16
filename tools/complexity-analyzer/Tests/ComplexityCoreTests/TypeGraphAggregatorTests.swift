import Testing
@testable import ComplexityCore

@Suite("타입 그래프 배선 — 유닛 부착")
struct TypeGraphAggregatorTests {

    private func typeUnit(_ name: String, _ line: Int) -> AnalyzedUnit {
        AnalyzedUnit(kind: .type, name: name, enclosingType: nil, file: "F.swift", line: line)
    }

    @Test("caller의 enclosing 타입으로 엣지를 만들어 측정을 부착한다")
    func attachesGraphMeasures() throws {
        // 타입 A(line 1)·B(line 2). A의 메소드 mA가 B를 참조 → 엣지 A→B.
        let stub = StubIndexProvider()
        stub.usrByLocation["A@F.swift:1"] = "uA"
        stub.usrByLocation["B@F.swift:2"] = "uB"
        stub.referencesByUSR["uB"] = [.init(callerUSRs: ["mA"])]
        stub.enclosingByUSR["mA"] = "uA"

        let patched = try TypeGraphAggregator.patched(
            units: [typeUnit("A", 1), typeUnit("B", 2)],
            index: stub,
            maxBlastHop: 2
        )
        let a = patched.first { $0.name == "A" }?.measurements
        let b = patched.first { $0.name == "B" }?.measurements
        #expect(a?.fanOut == 1)
        #expect(b?.fanOut == 0)
        #expect(b?.blastRadiusByHop == [1, 0, 0])
        #expect(a?.dependencyCycleSize == 1)
        #expect(a?.collaborationChainDepth == 2)
    }

    @Test("self-참조와 미해소 caller는 엣지에서 제외")
    func skipsSelfAndUnresolved() throws {
        let stub = StubIndexProvider()
        stub.usrByLocation["A@F.swift:1"] = "uA"
        stub.referencesByUSR["uA"] = [.init(callerUSRs: ["mA", "orphan"])]
        stub.enclosingByUSR["mA"] = "uA"   // self
        // "orphan"은 enclosingByUSR에 없음 → nil

        let patched = try TypeGraphAggregator.patched(units: [typeUnit("A", 1)], index: stub, maxBlastHop: 2)
        let a = patched.first { $0.name == "A" }?.measurements
        #expect(a?.fanOut == 0)
        #expect(a?.blastRadiusByHop == [0, 0, 0])
    }

    @Test("known 집합 밖 타입으로의 enclosing은 엣지 제외")
    func skipsEdgeToUnknownType() throws {
        let stub = StubIndexProvider()
        stub.usrByLocation["A@F.swift:1"] = "uA"
        stub.referencesByUSR["uA"] = [.init(callerUSRs: ["mExternal"])]
        stub.enclosingByUSR["mExternal"] = "uExternal"  // 유닛에 없는 타입

        let patched = try TypeGraphAggregator.patched(units: [typeUnit("A", 1)], index: stub, maxBlastHop: 2)
        #expect(patched.first { $0.name == "A" }?.measurements.blastRadiusByHop == [0, 0, 0])
    }

    @Test("메소드 유닛은 그래프 측정 미부착(패스스루)")
    func methodUnitsUntouched() throws {
        let stub = StubIndexProvider()
        let method = AnalyzedUnit(kind: .method, name: "m", enclosingType: "A", file: "F.swift", line: 3)
        let patched = try TypeGraphAggregator.patched(units: [method], index: stub, maxBlastHop: 2)
        #expect(patched.first?.measurements.fanOut == nil)
    }

    @Test("순환 멤버에 SCC 내 참조 타입(class/actor) 수가 부착된다")
    func attachesCycleReferenceCount() throws {
        // A(class) ↔ B(struct) 상호 참조 → 2-cycle. 참조 타입 1개(A) → 둘 다 count 1.
        let stub = StubIndexProvider()
        stub.usrByLocation["A@F.swift:1"] = "uA"
        stub.usrByLocation["B@F.swift:2"] = "uB"
        stub.referencesByUSR["uB"] = [.init(callerUSRs: ["mA"])]  // A→B
        stub.referencesByUSR["uA"] = [.init(callerUSRs: ["mB"])]  // B→A
        stub.enclosingByUSR["mA"] = "uA"
        stub.enclosingByUSR["mB"] = "uB"

        let units = [
            AnalyzedUnit(kind: .type, name: "A", enclosingType: nil, file: "F.swift", line: 1, typeDeclKind: .class),
            AnalyzedUnit(kind: .type, name: "B", enclosingType: nil, file: "F.swift", line: 2, typeDeclKind: .struct),
        ]
        let patched = try TypeGraphAggregator.patched(units: units, index: stub, maxBlastHop: 2)
        #expect(patched.first { $0.name == "A" }?.measurements.dependencyCycleSize == 2)
        #expect(patched.first { $0.name == "A" }?.measurements.cycleReferenceTypeCount == 1)
        #expect(patched.first { $0.name == "B" }?.measurements.cycleReferenceTypeCount == 1)
    }

    @Test("순환 아닌 타입은 cycleReferenceTypeCount nil")
    func nonCycleHasNilReferenceCount() throws {
        let stub = StubIndexProvider()
        stub.usrByLocation["A@F.swift:1"] = "uA"
        stub.usrByLocation["B@F.swift:2"] = "uB"
        stub.referencesByUSR["uB"] = [.init(callerUSRs: ["mA"])]  // A→B (일방)
        stub.enclosingByUSR["mA"] = "uA"
        let units = [
            AnalyzedUnit(kind: .type, name: "A", enclosingType: nil, file: "F.swift", line: 1, typeDeclKind: .struct),
            AnalyzedUnit(kind: .type, name: "B", enclosingType: nil, file: "F.swift", line: 2, typeDeclKind: .struct),
        ]
        let patched = try TypeGraphAggregator.patched(units: units, index: stub, maxBlastHop: 2)
        #expect(patched.first { $0.name == "A" }?.measurements.cycleReferenceTypeCount == nil)
    }

    @Test("타입 유닛이 있는데 USR 해소 0개면 stale로 throw (silent-0 방지)")
    func throwsWhenNoTypeResolves() {
        let stub = StubIndexProvider()  // usrByLocation 비어있음 → 해소 0
        #expect(throws: IndexStoreError.self) {
            try TypeGraphAggregator.patched(units: [typeUnit("A", 1)], index: stub, maxBlastHop: 2)
        }
    }
}
