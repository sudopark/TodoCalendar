import Testing
import Foundation
@testable import ComplexityCore

/// 실 IndexStoreDB 연결 스모크 — 로컬 DerivedData index가 있을 때만 돈다.
/// 목적은 값 검증이 아니라 "실 index를 물고 질의가 돈다"는 파이프라인 증명.
@Suite("IndexStoreDB 실연결 스모크 (로컬 전용)")
struct IndexStoreIntegrationTests {

    private static let libIndexStore =
        "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"

    private static var indexStorePath: String? {
        let base = ("~/Library/Developer/Xcode/DerivedData" as NSString).expandingTildeInPath
        guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: base) else { return nil }
        return dirs
            .filter { $0.hasPrefix("TodoCalendar-") }
            .map { "\(base)/\($0)/Index.noindex/DataStore" }
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    /// 리포 루트 — 이 테스트 파일(#filePath)에서 4단계 상위.
    /// .../TodoCalendar/tools/complexity-analyzer/Tests/ComplexityCoreTests/<이 파일>
    private static var repoRoot: String {
        (0..<5).reduce(#filePath) { path, _ in (path as NSString).deletingLastPathComponent }
    }

    @Test("실 index를 물고 fan-in 질의가 돈다")
    func realIndexQueryRuns() throws {
        guard let storePath = Self.indexStorePath,
              FileManager.default.fileExists(atPath: Self.libIndexStore)
        else {
            return  // 로컬 index/툴체인 없으면 스킵 (CI·타 머신)
        }

        // 실 소스에서 TodoEvent 선언 위치(file:line)를 얻어 정확 USR로 해소한다.
        let source = Self.repoRoot + "/Domain/Sources/Models/Events/Todo/TodoEvent.swift"
        guard let content = try? String(contentsOfFile: source, encoding: .utf8) else {
            return  // 소스 배치가 다르면 스킵
        }
        guard let todoEvent = SyntaxScanner().scan(source: content, file: source)
            .first(where: { $0.kind == .type && $0.name == "TodoEvent" })
        else {
            return
        }

        let dbPath = NSTemporaryDirectory() + "cx-idx-" + UUID().uuidString
        let provider = try IndexStoreDBProvider(
            storePath: storePath,
            databasePath: dbPath,
            libIndexStorePath: Self.libIndexStore
        )

        // 정확 USR 해소는 index가 이 소스 경로에서 빌드됐을 때만 성립.
        // nil이면 index가 다른 워크트리/체크아웃에서 빌드된 것 → 스모크 불가로 스킵.
        // (bare-name 시절과 달리 USR은 path-specific이라 워크트리 차이에 민감)
        guard let usr = provider.definitionUSR(named: "TodoEvent", file: source, line: todoEvent.line) else {
            return
        }

        // TodoEvent는 다수 참조되는 실존 타입 → 참조 질의가 실동작하면 > 0.
        // USR은 해소됐는데 0이면 "조용히 0" 회귀 신호(하한만 단정).
        #expect(provider.references(toUSR: usr).count > 0)
    }

    @Test("빈/없는 index store는 명시 throw (silent-0 방지)")
    func emptyOrMissingStoreThrows() throws {
        // 없는 경로
        #expect(throws: IndexStoreError.self) {
            try IndexStoreDBProvider.assertPopulated(storePath: NSTemporaryDirectory() + "nope-" + UUID().uuidString)
        }
        // 존재하지만 빈 디렉토리
        let empty = NSTemporaryDirectory() + "empty-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: empty) }
        #expect(throws: IndexStoreError.self) {
            try IndexStoreDBProvider.assertPopulated(storePath: empty)
        }
    }
}
