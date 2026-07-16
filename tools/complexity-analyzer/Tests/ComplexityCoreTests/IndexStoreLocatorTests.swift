import Testing
import Foundation
@testable import ComplexityCore

@Suite("IndexStoreLocator — 순수 탐색 로직")
struct IndexStoreLocatorTests {

    private func makeTempDir() throws -> String {
        let dir = NSTemporaryDirectory() + "cx-loc-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - 워크스페이스 추정

    @Test("source-root에서 상위로 올라가며 .xcworkspace를 찾는다")
    func findsWorkspaceAbove() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let repo = root + "/MyRepo"
        let src = repo + "/Domain/Sources"
        try FileManager.default.createDirectory(atPath: src, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: repo + "/App.xcworkspace", withIntermediateDirectories: true)

        #expect(IndexStoreLocator.workspacePath(above: src) == repo + "/App.xcworkspace")
    }

    @Test("워크스페이스가 없으면 nil")
    func noWorkspaceIsNil() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let src = root + "/loose/Sources"
        try FileManager.default.createDirectory(atPath: src, withIntermediateDirectories: true)
        #expect(IndexStoreLocator.workspacePath(above: src) == nil)
    }

    // MARK: - 후보 열거·정렬·필터

    /// populated DataStore(units 레코드 1개) + info.plist(WorkspacePath)를 가진 가짜 DerivedData 생성.
    private func makeDerivedData(_ ddRoot: String, name: String, workspace: String) throws -> String {
        let dd = ddRoot + "/" + name
        let units = dd + "/Index.noindex/DataStore/v5/units"
        try FileManager.default.createDirectory(atPath: units, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: units + "/u1", contents: Data("x".utf8))
        let plist: [String: Any] = ["WorkspacePath": workspace]
        (plist as NSDictionary).write(toFile: dd + "/info.plist", atomically: true)
        return dd + "/Index.noindex/DataStore"
    }

    @Test("workspace로 필터 — 매칭되는 DerivedData만 남긴다")
    func filtersByWorkspace() throws {
        let ddRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: ddRoot) }
        let mine = try makeDerivedData(ddRoot, name: "Proj-aaa", workspace: "/repo/mine.xcworkspace")
        _ = try makeDerivedData(ddRoot, name: "Proj-bbb", workspace: "/repo/other.xcworkspace")

        let stores = IndexStoreLocator.populatedDataStores(under: ddRoot, matchingWorkspace: "/repo/mine.xcworkspace")
        #expect(stores == [mine])
    }

    @Test("workspace nil이면 populated 전부, 최신 mtime 순")
    func allPopulatedNewestFirst() throws {
        let ddRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: ddRoot) }
        let older = try makeDerivedData(ddRoot, name: "Proj-old", workspace: "/repo/w.xcworkspace")
        let newer = try makeDerivedData(ddRoot, name: "Proj-new", workspace: "/repo/w.xcworkspace")
        // newer의 DataStore mtime을 미래로 밀어 최신으로 만든다.
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: 100)], ofItemAtPath: newer)

        let stores = IndexStoreLocator.populatedDataStores(under: ddRoot, matchingWorkspace: nil)
        #expect(stores.first == newer)
        #expect(Set(stores) == [older, newer])
    }

    @Test("populated 아닌(units 빈) DerivedData는 제외")
    func excludesEmptyStore() throws {
        let ddRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(atPath: ddRoot) }
        // units 디렉토리는 있으나 레코드 없음 → assertPopulated 실패 → 제외
        let empty = ddRoot + "/Proj-empty/Index.noindex/DataStore/v5/units"
        try FileManager.default.createDirectory(atPath: empty, withIntermediateDirectories: true)

        #expect(IndexStoreLocator.populatedDataStores(under: ddRoot, matchingWorkspace: nil).isEmpty)
    }
}
