import Foundation
import IndexStoreDB

/// 인덱스 상태 문제 — silent-0 fan-in을 막기 위한 명시 에러.
public enum IndexStoreError: Error, CustomStringConvertible {
    case storeMissing(String)
    case storeEmpty(String)
    case staleOrMismatched(typeUnitCount: Int)

    public var description: String {
        switch self {
        case .storeMissing(let path):
            return "index store 경로가 없음: \(path) — 대상 프로젝트를 빌드했는지 확인."
        case .storeEmpty(let path):
            return "index store에 unit 레코드가 없음: \(path) — 빌드가 인덱스를 생성하지 않았거나 경로가 잘못됨. (fan-in이 조용히 0으로 나오는 것을 방지)"
        case .staleOrMismatched(let count):
            return "index store가 현재 소스와 불일치 — 타입 \(count)개 중 USR 해소 0개. 대상을 (재)빌드한 뒤 다시 실행. (협업 측정이 조용히 전부 nil로 나가는 것을 방지)"
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

    /// `(name, file, line)`에 정의된 심볼의 정확한 USR.
    /// 이름으로 canonical occurrence를 순회하다 정의 role + 위치(파일·라인) 일치를 찾으면 그 USR.
    public func definitionUSR(named name: String, file: String, line: Int) -> String? {
        let targetPath = Self.resolvedPath(file)
        var found: String?
        index.forEachCanonicalSymbolOccurrence(byName: name) { occurrence in
            guard occurrence.roles.contains(.definition) else { return true }
            guard occurrence.location.line == line else { return true }
            guard Self.resolvedPath(occurrence.location.path) == targetPath else { return true }
            found = occurrence.symbol.usr
            return false // 찾았으니 순회 중단
        }
        return found
    }

    /// 이 USR을 참조하는 지점들 — 각 지점의 caller(calledBy/containedBy) USR 포함.
    public func references(toUSR usr: String) -> [ReferenceSite] {
        index.occurrences(ofUSR: usr, roles: .reference).map { occurrence in
            let callers = occurrence.relations
                .filter { $0.roles.contains(.calledBy) || $0.roles.contains(.containedBy) }
                .map { $0.symbol.usr }
            return ReferenceSite(callerUSRs: callers)
        }
    }

    /// 심볼을 감싸는 최근접 명목 타입 USR. childOf 관계를 타고 올라가며 판정.
    /// - 부모가 struct/class/enum/protocol → 그 USR
    /// - 부모가 extension → 확장 대상 명목 타입으로 해소(extension USR은 타입 USR이 아님)
    /// - 부모가 중첩 함수 등 → 한 단계 더 위로 (깊이 상한 8)
    public func enclosingTypeUSR(of usr: String) -> String? {
        resolveEnclosingType(of: usr, depth: 0)
    }

    private func resolveEnclosingType(of usr: String, depth: Int) -> String? {
        guard depth < 8 else { return nil }
        guard let def = index.occurrences(ofUSR: usr, roles: .definition).first else { return nil }
        if Self.isNominalType(def.symbol.kind) { return usr }
        guard let parent = def.relations.first(where: { $0.roles.contains(.childOf) })?.symbol
        else { return nil }
        if Self.isNominalType(parent.kind) { return parent.usr }
        if parent.kind == .extension {
            // extension USR과 관련된 occurrence엔 확장 대상 타입(extendedBy)뿐 아니라
            // 그 extension 본문의 중첩 명목 타입(childOf)도 섞인다. 둘 다 nominal이라
            // kind만으로 고르면 중첩 타입을 오인할 수 있으므로 extendedBy role로 가른다.
            let candidates = index.occurrences(relatedToUSR: parent.usr, roles: .all)
                .map { (isExtendedBy: $0.roles.contains(.extendedBy),
                        isNominal: Self.isNominalType($0.symbol.kind),
                        usr: $0.symbol.usr) }
            return Self.pickExtendedType(candidates)
        }
        return resolveEnclosingType(of: parent.usr, depth: depth + 1)
    }

    /// extension 관련 occurrence 후보 중 확장 대상 명목 타입만 고른다(중첩 멤버 타입 제외).
    /// occurrence 반환 순서 보장이 없으므로 role로 확정 — 순서 무관하게 결정적.
    static func pickExtendedType(
        _ candidates: [(isExtendedBy: Bool, isNominal: Bool, usr: String)]
    ) -> String? {
        candidates.first { $0.isExtendedBy && $0.isNominal }?.usr
    }

    /// index가 명목 타입으로 인덱싱하는 kind (actor는 .class로 들어옴).
    private static func isNominalType(_ kind: IndexSymbolKind) -> Bool {
        switch kind {
        case .struct, .class, .enum, .protocol: return true
        default: return false
        }
    }

    /// 경로 비교 정규화 — /private 심볼릭·상대 표기 차이를 흡수.
    private static func resolvedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }
}
