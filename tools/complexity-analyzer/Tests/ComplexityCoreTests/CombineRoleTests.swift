import Testing
@testable import ComplexityCore

@Suite("Combine 역할 혼합 — 순수 변형 연산자 클로저의 side-effect")
struct CombineRoleTests {

    private func method(_ source: String) -> Measurements {
        SyntaxScanner().scan(source: source, file: "T.swift")
            .first { $0.kind == .method }?.measurements ?? .init()
    }

    @Test("map 클로저 안 self 대입 = 역할 혼합 1")
    func mapSideEffect() {
        #expect(method("struct S { func f() { _ = pub.map { self.x = $0; return $0 } } }").combineRoleMix == 1)
    }

    @Test("handleEvents 클로저 side-effect는 역할 혼합 아님 = 0")
    func handleEventsAllowed() {
        #expect(method("struct S { func f() { _ = pub.handleEvents(receiveOutput: { self.x = $0 }) } }").combineRoleMix == 0)
    }

    @Test("역할 혼합은 query/command 무관 — command에서도 잡힌다")
    func independentOfQuery() {
        let m = method("struct S { func f() { _ = pub.filter { self.x = $0; return true } } }")
        #expect(m.combineRoleMix == 1)
        #expect(m.cqsViolations == nil)   // command라 CQS는 N/A
    }
}
