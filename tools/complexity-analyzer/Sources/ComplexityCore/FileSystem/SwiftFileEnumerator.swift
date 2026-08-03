import Foundation

/// 스캔 대상 .swift 파일 열거. 빌드 산출물(.build)과 테스트 코드는 측정 대상에서 제외한다.
/// (테스트 더블·헬퍼는 의도적 반복·저응집이라 복잡도로 오탐됨 — 이슈 #691 측정 전제)
enum SwiftFileEnumerator {

    /// 경로에 이게 있으면 테스트 코드로 본다 (테스트 타겟·더블·헬퍼·스냅샷 디렉토리).
    private static let testPathMarkers = ["/Tests/", "/DomainTests/", "/TestDoubles/", "/Snapshots/", "TestHelpKit"]
    /// 테스트 더블·프리뷰 더미 접두 (StubXxx·FakeXxx·DummyXxx 등). 파일명·타입명 공용.
    static let testDoublePrefixes = ["Stub", "Spy", "Mock", "Fake", "Dummy"]

    /// 타입명이 테스트 더블·프리뷰 더미 접두인가. production 파일 안 프리뷰 더미(DummyXxxViewModel 등)를
    /// 파일 경로로는 못 걸러 타입명으로도 제외한다.
    static func isTestDoubleName(_ name: String) -> Bool {
        testDoublePrefixes.contains { name.hasPrefix($0) }
    }

    static func files(under root: String, scope: Scope) -> [String] {
        // 명시 파일 지정은 사용자 의도 — 테스트 필터를 적용하지 않는다.
        if case .file(let path) = scope { return [path] }

        let url = URL(fileURLWithPath: root)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var result: [String] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            if fileURL.path.contains("/.build/") { continue }
            if isTestCode(fileURL.path) { continue }
            result.append(fileURL.path)
        }
        return result.sorted()
    }

    /// 테스트 코드 판별 — 경로/타겟 마커 또는 테스트 더블 파일명 접두 + `*Tests.swift` 접미.
    static func isTestCode(_ path: String) -> Bool {
        if testPathMarkers.contains(where: { path.contains($0) }) { return true }
        let name = (path as NSString).lastPathComponent
        if name.hasSuffix("Tests.swift") { return true }
        let base = (name as NSString).deletingPathExtension
        return testDoublePrefixes.contains { base.hasPrefix($0) }
    }
}
