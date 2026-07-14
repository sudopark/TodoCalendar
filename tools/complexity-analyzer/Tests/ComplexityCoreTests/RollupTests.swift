import Testing
@testable import ComplexityCore

@Suite("타입 롤업 — 소속 메소드 측정 합산")
struct RollupTests {

    private func type(_ source: String, name: String) -> Measurements? {
        SyntaxScanner().scan(source: source, file: "T.swift")
            .first { $0.kind == .type && $0.name == name }?.measurements
    }

    @Test("소속 메소드의 internalComplexity 합이 타입에 실린다")
    func rollsUpInternalComplexity() {
        // f: if a{} = 1, g: if a{ if b{} } = 3 → 합 4
        let m = type("struct S { func f() { if a {} }; func g() { if a { if b {} } } }", name: "S")
        #expect(m?.rolledUpInternalComplexity == 4)
    }

    @Test("cqsViolations·combineRoleMix도 합산(nil은 0으로)")
    func rollsUpEffectMeasures() {
        // q: query self.x=1 → cqs 1. c: command → cqs 0. map 역할혼합 1건.
        let src = """
        struct S {
            func q() -> Int { self.x = 1; return x }
            func c() { _ = pub.map { self.y = $0; return $0 } }
        }
        """
        let m = type(src, name: "S")
        #expect(m?.rolledUpCqsViolations == 1)
        #expect(m?.rolledUpCombineRoleMix == 1)
    }

    @Test("한 파일 내 extension 메소드도 원본 타입으로 롤업")
    func rollsUpExtensionMethods() {
        let src = "struct S { func f() { if a {} } }\nextension S { func g() { if a { if b {} } } }"
        #expect(type(src, name: "S")?.rolledUpInternalComplexity == 4)
    }

    @Test("동명 nested 타입은 enclosing으로 분리 — 롤업 안 섞임")
    func nestedSameNameNotMerged() {
        let src = """
        struct A { struct Entity { func f() { if x {} } } }
        struct B { struct Entity { func g() { if x { if y {} } } } }
        """
        let units = SyntaxScanner().scan(source: src, file: "T.swift")
        let aEntity = units.first { $0.kind == .type && $0.name == "Entity" && $0.enclosingType == "A" }
        let bEntity = units.first { $0.kind == .type && $0.name == "Entity" && $0.enclosingType == "B" }
        #expect(aEntity?.measurements.rolledUpInternalComplexity == 1)
        #expect(bEntity?.measurements.rolledUpInternalComplexity == 3)
    }
}
