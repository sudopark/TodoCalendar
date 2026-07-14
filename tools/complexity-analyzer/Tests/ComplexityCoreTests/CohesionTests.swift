import Testing
@testable import ComplexityCore

@Suite("응집 — LCOM·내부 결합·체인 깊이 (순수 함수)")
struct CohesionTests {

    @Test("공유 프로퍼티로 이어진 메소드는 한 요소")
    func sharedPropConnects() {
        let methods = [
            MethodNode(name: "a", referencedProps: ["x"], calledMethods: []),
            MethodNode(name: "b", referencedProps: ["x"], calledMethods: []),
        ]
        #expect(CohesionAnalyzer.metrics(methods: methods).lcom == 1)
    }

    @Test("공유 없는 두 메소드는 두 요소(분리 후보)")
    func disjointMethodsSplit() {
        let methods = [
            MethodNode(name: "a", referencedProps: ["x"], calledMethods: []),
            MethodNode(name: "b", referencedProps: ["y"], calledMethods: []),
        ]
        #expect(CohesionAnalyzer.metrics(methods: methods).lcom == 2)
    }

    @Test("호출 관계도 연결로 본다")
    func callConnects() {
        let methods = [
            MethodNode(name: "a", referencedProps: ["x"], calledMethods: ["b"]),
            MethodNode(name: "b", referencedProps: ["y"], calledMethods: []),
        ]
        #expect(CohesionAnalyzer.metrics(methods: methods).lcom == 1)
    }

    @Test("메소드 없으면 0")
    func emptyIsZero() {
        #expect(CohesionAnalyzer.metrics(methods: []).lcom == 0)
    }

    @Test("내부 호출 결합 = 타입 내부 메소드 호출 간선 수")
    func internalCouplingCountsEdges() {
        let methods = [
            MethodNode(name: "a", referencedProps: [], calledMethods: ["b", "c"]),
            MethodNode(name: "b", referencedProps: [], calledMethods: ["c"]),
            MethodNode(name: "c", referencedProps: [], calledMethods: []),
        ]
        // a→b, a→c, b→c = 3
        #expect(CohesionAnalyzer.metrics(methods: methods).internalCoupling == 3)
    }

    @Test("외부 호출(타입 밖 이름)은 결합에서 제외")
    func externalCallsExcluded() {
        let methods = [
            MethodNode(name: "a", referencedProps: [], calledMethods: ["external"]),
            MethodNode(name: "b", referencedProps: [], calledMethods: []),
        ]
        #expect(CohesionAnalyzer.metrics(methods: methods).internalCoupling == 0)
    }

    @Test("체인 깊이 = 가장 긴 내부 호출 경로의 메소드 수")
    func chainDepthLongestPath() {
        let methods = [
            MethodNode(name: "a", referencedProps: [], calledMethods: ["b"]),
            MethodNode(name: "b", referencedProps: [], calledMethods: ["c"]),
            MethodNode(name: "c", referencedProps: [], calledMethods: []),
        ]
        // a→b→c = 3
        #expect(CohesionAnalyzer.metrics(methods: methods).maxCallChainDepth == 3)
    }

    @Test("사이클 있어도 유한(방문 가드)")
    func chainDepthCycleSafe() {
        let methods = [
            MethodNode(name: "a", referencedProps: [], calledMethods: ["b"]),
            MethodNode(name: "b", referencedProps: [], calledMethods: ["a"]),
        ]
        #expect(CohesionAnalyzer.metrics(methods: methods).maxCallChainDepth == 2)
    }
}
