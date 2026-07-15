import Testing
@testable import ComplexityCore

@Suite("protocol 타입 유닛 방출")
struct ProtocolUnitTests {

    private func units(_ source: String) -> [AnalyzedUnit] {
        SyntaxScanner().scan(source: source, file: "P.swift")
    }

    @Test("protocol 선언이 타입 유닛으로 방출된다")
    func protocolEmitsTypeUnit() {
        let us = units("protocol Drawable { func draw() -> Int }")
        #expect(us.contains { $0.kind == .type && $0.name == "Drawable" })
    }

    @Test("protocol requirement는 enclosingType이 protocol인 메소드 유닛")
    func requirementIsMethodUnitOfProtocol() {
        let us = units("protocol Drawable { func draw() -> Int }")
        let draw = us.first { $0.kind == .method && $0.name == "draw" }
        #expect(draw?.enclosingType == "Drawable")
    }

    @Test("protocol 스택 push/pop이 형제 타입을 오염시키지 않는다")
    func nestedUnderProtocolTracked() {
        let us = units("protocol P { func f() }\nstruct S { func g() { if a {} } }")
        let s = us.first { $0.kind == .type && $0.name == "S" }
        #expect(s?.enclosingType == nil)
        #expect(s?.measurements.rolledUpInternalComplexity == 1)
    }
}
