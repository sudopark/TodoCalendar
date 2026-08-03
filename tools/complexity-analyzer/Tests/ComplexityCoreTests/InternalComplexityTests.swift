import Testing
@testable import ComplexityCore

@Suite("내부 복잡도 측정 — 분기·중첩 가중")
struct InternalComplexityTests {

    private func score(_ source: String) -> Int {
        let units = SyntaxScanner().scan(source: source, file: "T.swift")
        #expect(units.count == 1)
        return units.first?.measurements.internalComplexity ?? -1
    }

    @Test("제어흐름 없으면 0")
    func plain() {
        #expect(score("func f() { let x = 1; _ = x }") == 0)
    }

    @Test("단일 if = 1 (depth 0)")
    func singleIf() {
        #expect(score("func f() { if flag { doThing() } }") == 1)
    }

    @Test("for 안의 if = 중첩 가중 (1 + 2) = 3")
    func nested() {
        #expect(score("func f() { for i in items { if i > 0 { use(i) } } }") == 3)
    }

    @Test("guard + 형제 while = 1 + 1 = 2")
    func guardAndLoop() {
        #expect(score("func f() { guard ok else { return }; while run { step() } }") == 2)
    }

    @Test("flat switch 2 cases = 1 + 1 = 2")
    func flatSwitch() {
        #expect(score("func f() { switch v { case .a: doA(); case .b: doB() } }") == 2)
    }

    @Test("else-if 사다리는 flat = 1 + 1 + 1 = 3 (중첩 폭증 아님)")
    func elseIfChainIsFlat() {
        #expect(score("func f() { if a { x() } else if b { y() } else if c { z() } }") == 3)
    }

    @Test("repeat-while = 1")
    func repeatWhile() {
        #expect(score("func f() { repeat { step() } while run }") == 1)
    }

    @Test("do-catch = 1")
    func doCatch() {
        #expect(score("func f() { do { try work() } catch { handle() } }") == 1)
    }

    @Test("boolean 연산자·삼항은 페이즈 1 무가중 (스코프 축소 pin)")
    func booleanAndTernaryUnweighted() {
        // 플랜 Task2는 &&/||/삼항을 대상 노드로 명시했으나 페이즈 1은 의도적으로 미포함.
        // 회귀 시 즉시 드러나게 현재 동작을 고정한다.
        #expect(score("func f() { if a && b || c { x() } }") == 1)
        #expect(score("func f() { let x = c ? 1 : 2; _ = x }") == 0)
    }

    @Test("메소드의 enclosing type 포착")
    func enclosingType() {
        let units = SyntaxScanner().scan(
            source: "struct S { func m() { if x {} } }",
            file: "T.swift"
        )
        let method = units.first { $0.kind == .method }
        #expect(method?.enclosingType == "S")
        #expect(method?.name == "m")
        #expect(units.contains { $0.kind == .type && $0.name == "S" })
    }
}
