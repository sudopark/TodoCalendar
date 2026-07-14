import Testing
@testable import ComplexityCore

@Suite("응집 — scanner 통합(멤버 그래프 → 지표)")
struct CohesionScanTests {

    private func measure(_ source: String, name: String) -> Measurements? {
        SyntaxScanner().scan(source: source, file: "T.swift")
            .first { $0.kind == .type && $0.name == name }?.measurements
    }

    @Test("공유 stored property를 쓰는 메소드는 한 요소")
    func sharedStoredProp() {
        let src = """
        struct S {
            var x = 0
            func a() { self.x = 1 }
            func b() { print(x) }
        }
        """
        #expect(measure(src, name: "S")?.lcom == 1)
    }

    @Test("서로 다른 프로퍼티만 쓰는 두 메소드는 두 요소")
    func disjoint() {
        let src = """
        struct S {
            var x = 0
            var y = 0
            func a() { self.x = 1 }
            func b() { self.y = 1 }
        }
        """
        #expect(measure(src, name: "S")?.lcom == 2)
    }

    @Test("메소드 호출로 이어지면 한 요소")
    func connectedByCall() {
        let src = """
        struct S {
            var x = 0
            var y = 0
            func a() { self.x = 1; b() }
            func b() { self.y = 1 }
        }
        """
        #expect(measure(src, name: "S")?.lcom == 1)
    }

    @Test("내부 호출 결합·체인 깊이가 타입에 실린다")
    func couplingAndDepthAttached() {
        let src = """
        struct S {
            func a() { b() }
            func b() { c() }
            func c() {}
        }
        """
        let m = measure(src, name: "S")
        #expect(m?.internalCoupling == 2)      // a→b, b→c
        #expect(m?.maxCallChainDepth == 3)     // a→b→c
    }

    @Test("computed property는 stored 아님 — 응집 연결에 안 쓰임")
    func computedNotStored() {
        // a·b가 computed c만 참조하면 stored 공유 없음 → 두 요소.
        let src = """
        struct S {
            var c: Int { 0 }
            func a() { _ = self.c }
            func b() { _ = self.c }
        }
        """
        #expect(measure(src, name: "S")?.lcom == 2)
    }
}
