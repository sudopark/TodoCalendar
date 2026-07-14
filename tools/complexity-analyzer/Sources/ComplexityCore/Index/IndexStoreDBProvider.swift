import Foundation
import IndexStoreDB

/// IndexStoreDB 실 구현 — 빌드가 만든 index store를 읽어 fan-in을 해소한다.
public struct IndexStoreDBProvider: IndexProviding {

    private let index: IndexStoreDB

    /// - storePath: `DerivedData/<proj>-<hash>/Index.noindex/DataStore`
    /// - databasePath: 쓰기 가능한 임시 경로 (IndexStoreDB 작업 DB)
    /// - libIndexStorePath: 툴체인의 `libIndexStore.dylib`
    public init(storePath: String, databasePath: String, libIndexStorePath: String) throws {
        let library = try IndexStoreLibrary(dylibPath: libIndexStorePath)
        self.index = try IndexStoreDB(
            storePath: storePath,
            databasePath: databasePath,
            library: library,
            waitUntilDoneInitializing: true
        )
        index.pollForUnitChangesAndWait()
    }

    public func typeUSRs(named name: String) -> [String] {
        var usrs: Set<String> = []
        index.forEachCanonicalSymbolOccurrence(byName: name) { occurrence in
            let kind = occurrence.symbol.kind
            let isNominalType = kind == .class || kind == .struct || kind == .enum || kind == .protocol
            if occurrence.roles.contains(.definition), isNominalType {
                usrs.insert(occurrence.symbol.usr)
            }
            return true
        }
        return Array(usrs)
    }

    public func referenceCount(ofUSR usr: String) -> Int {
        index.occurrences(ofUSR: usr, roles: .reference).count
    }
}
