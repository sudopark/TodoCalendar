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

    @Test("실 index를 물고 fan-in 질의가 돈다")
    func realIndexQueryRuns() throws {
        guard let storePath = Self.indexStorePath,
              FileManager.default.fileExists(atPath: Self.libIndexStore)
        else {
            return  // 로컬 index/툴체인 없으면 스킵 (CI·타 머신)
        }

        let dbPath = NSTemporaryDirectory() + "cx-idx-" + UUID().uuidString
        let provider = try IndexStoreDBProvider(
            storePath: storePath,
            databasePath: dbPath,
            libIndexStorePath: Self.libIndexStore
        )

        // 연결·질의가 크래시 없이 돌면 스모크 성공. (값은 인덱스 상태 의존이라 단정 안 함)
        let count = FanIn(index: provider).count(forTypeNamed: "TodoEvent")
        #expect(count >= 0)
    }
}
