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
