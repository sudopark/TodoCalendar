import Testing
@testable import ComplexityCore

@Suite("CQS — query 함수 메인 흐름의 side-effect 노출")
struct CQSTests {

    private func method(_ source: String) -> Measurements {
        SyntaxScanner().scan(source: source, file: "T.swift")
            .first { $0.kind == .method }?.measurements ?? .init()
    }

    @Test("query 메인 흐름의 self 대입 = 위반 1")
    func queryMainFlowAssignment() {
        #expect(method("struct S { func f() -> Int { self.x = 1; return x } }").cqsViolations == 1)
    }

    @Test("query의 .send 방출 = 위반 1")
    func querySend() {
        #expect(method("struct S { func f() -> Int { subject.send(1); return 0 } }").cqsViolations == 1)
    }

    @Test("command(Void) 함수는 CQS 대상 아님 = nil")
    func commandNotMeasured() {
        #expect(method("struct S { func f() { self.x = 1 } }").cqsViolations == nil)
    }

    @Test("query라도 handleEvents 클로저 안 side-effect는 제외 = 0")
    func allowedClosureExcluded() {
        #expect(method("struct S { func f() -> P { pub.handleEvents(receiveOutput: { self.x = $0 }) } }").cqsViolations == 0)
    }

    @Test("로컬 var 대입은 side-effect 아님 (self/member 대입만)")
    func localVarNotSideEffect() {
        #expect(method("struct S { func f() -> Int { var n = 0; n = 1; return n } }").cqsViolations == 0)
    }

    @Test("중첩 함수 안 side-effect는 바깥 메소드로 새지 않는다")
    func nestedFunctionScopeIsolated() {
        // outer는 `return 0`뿐인 순수 query — inner의 self.x=1이 새어들면 안 됨.
        let outer = SyntaxScanner()
            .scan(source: "struct S { func outer() -> Int { func inner() { self.x = 1 }; return 0 } }", file: "T.swift")
            .first { $0.name == "outer" }
        #expect(outer?.measurements.cqsViolations == 0)
    }

    @Test("Swift.Void·공백 빈 튜플 반환은 command = nil")
    func voidVariantsAreCommand() {
        #expect(method("struct S { func f() -> Swift.Void { self.x = 1 } }").cqsViolations == nil)
        #expect(method("struct S { func f() -> ( ) { self.x = 1 } }").cqsViolations == nil)
    }
}
