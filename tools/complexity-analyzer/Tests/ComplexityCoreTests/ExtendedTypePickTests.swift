import Testing
@testable import ComplexityCore

@Suite("extension 확장 대상 타입 선택 — 중첩 타입 오인 방지")
struct ExtendedTypePickTests {

    // 실측 구조: extension 관련 occurrence = 확장 대상(extendedBy) + 본문 중첩 타입(childOf).
    // 둘 다 nominal이라 role로만 갈린다.
    private let extended = (isExtendedBy: true, isNominal: true, usr: "uExtended")
    private let nested = (isExtendedBy: false, isNominal: true, usr: "uNested")

    @Test("extendedBy인 확장 대상만 고른다 (중첩 타입 제외)")
    func picksExtendedNotNested() {
        #expect(IndexStoreDBProvider.pickExtendedType([extended, nested]) == "uExtended")
    }

    @Test("occurrence 순서가 뒤바뀌어도 결정적으로 확장 대상")
    func orderIndependent() {
        #expect(IndexStoreDBProvider.pickExtendedType([nested, extended]) == "uExtended")
    }

    @Test("extendedBy 후보 없으면 nil")
    func nilWhenNoExtended() {
        #expect(IndexStoreDBProvider.pickExtendedType([nested]) == nil)
    }

    @Test("extendedBy지만 non-nominal(있을 리 없는 방어)은 제외")
    func excludesNonNominalExtended() {
        let weird = (isExtendedBy: true, isNominal: false, usr: "uWeird")
        #expect(IndexStoreDBProvider.pickExtendedType([weird, extended]) == "uExtended")
    }
}
