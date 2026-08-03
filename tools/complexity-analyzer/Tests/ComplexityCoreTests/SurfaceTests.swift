import Testing
@testable import ComplexityCore

@Suite("노출 표면적 — public/open 멤버 수")
struct SurfaceTests {

    private func surface(_ source: String, name: String) -> Int? {
        SyntaxScanner().scan(source: source, file: "T.swift")
            .first { $0.kind == .type && $0.name == name }?.measurements.publicSurface
    }

    @Test("public 메소드·프로퍼티만 센다")
    func countsPublicMembers() {
        let src = """
        struct S {
            public var a: Int = 0
            var b: Int = 0
            public func f() {}
            func g() {}
            open func h() {}
        }
        """
        // public a, public f, open h = 3
        #expect(surface(src, name: "S") == 3)
    }

    @Test("public 멤버 없으면 0")
    func zeroWhenNoPublic() {
        #expect(surface("struct S { var a: Int = 0; func f() {} }", name: "S") == 0)
    }

    @Test("extension의 public 멤버도 원본 타입 표면적에 합산")
    func includesExtensionPublicMembers() {
        let src = "struct S { public func f() {} }\nextension S { public func g() {} }"
        #expect(surface(src, name: "S") == 2)
    }
}
