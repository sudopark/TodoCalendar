import Foundation

/// 스캔 대상 .swift 파일 열거. (테스트 코드 제외 정책은 후속 페이즈 — 여기선 빌드 산출물만 회피)
enum SwiftFileEnumerator {

    static func files(under root: String, scope: Scope) -> [String] {
        if case .file(let path) = scope { return [path] }

        let url = URL(fileURLWithPath: root)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var result: [String] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            if fileURL.path.contains("/.build/") { continue }
            result.append(fileURL.path)
        }
        return result.sorted()
    }
}
