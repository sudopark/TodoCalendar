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

    @Test("타입 유닛에 선언 종류가 실린다")
    func typeDeclKindCaptured() {
        let us = units("protocol P { func f() }\nstruct S {}\nenum E { case a }\nclass C {}")
        func kind(_ n: String) -> AnalyzedUnit.TypeDeclKind? {
            us.first { $0.kind == .type && $0.name == n }?.typeDeclKind
        }
        #expect(kind("P") == .protocol)
        #expect(kind("S") == .struct)
        #expect(kind("E") == .enum)
        #expect(kind("C") == .class)
    }

    @Test("protocol·enum은 LCOM 비적용(nil), struct/class는 적용")
    func lcomExcludedForProtocolAndEnum() {
        // 각 타입에 서로 안 엮이는 메소드 2개 → struct/class면 LCOM>1로 잡히지만
        // protocol·enum은 nil이어야(과탐 제외).
        let body = "func a() { print(x) }\n  func b() { print(y) }"
        func lcom(_ decl: String) -> Int? {
            SyntaxScanner().scan(source: "\(decl) T { \(body) }", file: "T.swift")
                .first { $0.kind == .type && $0.name == "T" }?.measurements.lcom
        }
        #expect(lcom("struct") != nil)
        #expect(lcom("class") != nil)
        #expect(lcom("enum") == nil)
        #expect(lcom("protocol") == nil)
    }
}
