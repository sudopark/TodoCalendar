import Foundation
import IndexStoreDB

/// 인덱스 상태 문제 — silent-0 fan-in을 막기 위한 명시 에러.
public enum IndexStoreError: Error, CustomStringConvertible {
    case storeMissing(String)
    case storeEmpty(String)

    public var description: String {
        switch self {
        case .storeMissing(let path):
            return "index store 경로가 없음: \(path) — 대상 프로젝트를 빌드했는지 확인."
        case .storeEmpty(let path):
            return "index store에 unit 레코드가 없음: \(path) — 빌드가 인덱스를 생성하지 않았거나 경로가 잘못됨. (fan-in이 조용히 0으로 나오는 것을 방지)"
        }
    }
}

/// IndexStoreDB 실 구현 — 빌드가 만든 index store를 읽어 fan-in을 해소한다.
public struct IndexStoreDBProvider: IndexProviding {

    private let index: IndexStoreDB

    /// - storePath: `DerivedData/<proj>-<hash>/Index.noindex/DataStore`
    /// - databasePath: 쓰기 가능한 임시 경로 (IndexStoreDB 작업 DB)
    /// - libIndexStorePath: 툴체인의 `libIndexStore.dylib`
    public init(storePath: String, databasePath: String, libIndexStorePath: String) throws {
        // 라이브러리 로드 전에 store가 실제로 채워졌는지 먼저 검증한다.
        // (없거나 빈 store여도 IndexStoreDB init은 throw 안 하고, 모든 fan-in이 조용히 0이 됨)
        try Self.assertPopulated(storePath: storePath)

        let library = try IndexStoreLibrary(dylibPath: libIndexStorePath)
        self.index = try IndexStoreDB(
            storePath: storePath,
            databasePath: databasePath,
            library: library,
            waitUntilDoneInitializing: true
        )
        index.pollForUnitChangesAndWait()
    }

    /// store가 존재하고 unit 레코드를 실제로 담고 있는지 확인.
    /// 빈/없는 store를 조용히 fan-in 0으로 흘리지 않도록 명시 throw.
    static func assertPopulated(storePath: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: storePath, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw IndexStoreError.storeMissing(storePath)
        }

        // DataStore 레이아웃: `v<n>/units/<레코드>`. 하나라도 unit이 있어야 실질 인덱스.
        let versionDirs = (try? fileManager.contentsOfDirectory(atPath: storePath)) ?? []
        let hasUnits = versionDirs.contains { version in
            let unitsPath = storePath + "/" + version + "/units"
            let entries = (try? fileManager.contentsOfDirectory(atPath: unitsPath)) ?? []
            return !entries.isEmpty
        }
        guard hasUnits else { throw IndexStoreError.storeEmpty(storePath) }
    }

    // 알려진 한계 (→ 페이즈 3에서 해소): 타입을 bare name으로 전역 조회한다.
    // 동명이인 타입(예: SQLite 테이블마다 있는 Entity/Columns)이 한 이름으로 합산된다.
    // 정확한 식별은 USR 또는 enclosing 체인 기반 정규화가 필요.
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
