import Testing
@testable import ComplexityCore

@Suite("타입 의존 그래프 raw 측정")
struct TypeGraphTests {

    private func graph(_ nodes: [String], _ edges: [(String, String)]) -> TypeDependencyGraph {
        TypeDependencyGraph(
            nodes: Set(nodes),
            edges: edges.map { .init(from: $0.0, to: $0.1) }
        )
    }

    @Test("fan-out = distinct 외부 의존 수 (self·중복 제외)")
    func fanOutDistinct() {
        // A→B, A→C, A→B(중복), A→A(self)
        let m = graph(["A", "B", "C"], [("A","B"), ("A","C"), ("A","B"), ("A","A")])
            .measures(maxBlastHop: 2)
        #expect(m["A"]?.fanOut == 2)
        #expect(m["B"]?.fanOut == 0)
    }

    @Test("cycle 크기 = SCC 크기 (사이클 없으면 1)")
    func cycleSizeIsSCC() {
        // A→B→C→A 순환, D는 고립
        let m = graph(["A","B","C","D"], [("A","B"), ("B","C"), ("C","A")])
            .measures(maxBlastHop: 2)
        #expect(m["A"]?.cycleSize == 3)
        #expect(m["B"]?.cycleSize == 3)
        #expect(m["C"]?.cycleSize == 3)
        #expect(m["D"]?.cycleSize == 1)
    }

    @Test("2-노드 상호 의존도 cycle 크기 2")
    func twoNodeCycle() {
        let m = graph(["A","B"], [("A","B"), ("B","A")]).measures(maxBlastHop: 2)
        #expect(m["A"]?.cycleSize == 2)
    }

    @Test("chain depth = outbound 최장 경로 노드 수")
    func chainDepthLongestPath() {
        // A→B→C→D 선형, leaf는 1
        let m = graph(["A","B","C","D"], [("A","B"), ("B","C"), ("C","D")])
            .measures(maxBlastHop: 2)
        #expect(m["A"]?.chainDepth == 4)
        #expect(m["D"]?.chainDepth == 1)
    }

    @Test("사이클은 한 SCC 층으로 접혀 chain depth 1 (결정적·대칭)")
    func chainDepthCycleCollapses() {
        let m = graph(["A","B"], [("A","B"), ("B","A")]).measures(maxBlastHop: 2)
        // A·B가 한 SCC → 응축 DAG 단일 노드 → 둘 다 depth 1 (방문 순서 무관).
        #expect(m["A"]?.chainDepth == 1)
        #expect(m["B"]?.chainDepth == 1)
    }

    @Test("사이클 SCC 위에 꼬리가 붙으면 층 수로 chain depth")
    func chainDepthThroughCycle() {
        // {A,B} 사이클 + A→C. 응축: {AB}→{C}. depth({AB})=2, depth(C)=1.
        let m = graph(["A","B","C"], [("A","B"), ("B","A"), ("A","C")])
            .measures(maxBlastHop: 2)
        #expect(m["A"]?.chainDepth == 2)
        #expect(m["B"]?.chainDepth == 2)
        #expect(m["C"]?.chainDepth == 1)
    }

    @Test("blast radius = 역방향 per-hop 전이 의존자 수 (dedup·zero-fill)")
    func blastByHopReverse() {
        // 엣지 X→Y = X가 Y 의존. blast(Y) = Y를 의존하는 X 전이.
        // 엣지: A→B, B→C, A→C. blast(C): 직접 의존자 {A,B}=2(hop0), 그 위 없음 → [2,0,0].
        let m = graph(["A","B","C"], [("A","B"), ("B","C"), ("A","C")])
            .measures(maxBlastHop: 2)
        #expect(m["C"]?.blastByHop == [2, 0, 0])
        // blast(B): 직접 의존자 {A}(hop0). A의 의존자 없음 → [1,0,0].
        #expect(m["B"]?.blastByHop == [1, 0, 0])
        // blast(A): 의존자 없음 → [0,0,0].
        #expect(m["A"]?.blastByHop == [0, 0, 0])
    }

    @Test("blast per-hop은 홉별로 새로 도달한 노드만 (재방문 제외)")
    func blastDedupAcrossHops() {
        // 체인 D→C→B→A : blast(A) hop0={B}, hop1={C}, hop2={D}
        let m = graph(["A","B","C","D"], [("B","A"), ("C","B"), ("D","C")])
            .measures(maxBlastHop: 2)
        #expect(m["A"]?.blastByHop == [1, 1, 1])
    }
}
