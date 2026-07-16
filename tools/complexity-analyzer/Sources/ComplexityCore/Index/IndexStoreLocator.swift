import Foundation

public enum IndexStoreLocatorError: Error, CustomStringConvertible {
    case noCandidates(derivedDataRoot: String)
    case noResolvingStore(sourceRoot: String, tried: Int)

    public var description: String {
        switch self {
        case .noCandidates(let root):
            return "DerivedData(\(root))에 populated index store가 없음 — 대상 워크트리를 한 번 빌드했는지 확인."
        case .noResolvingStore(let root, let tried):
            return "\(root)의 소스를 해소하는 index store를 못 찾음 (후보 \(tried)개 시도). 이 워크트리를 빌드한 뒤 다시 실행."
        }
    }
}

/// `--index-store-path`를 생략하면, 현재 source-root(워크트리)의 소스를 실제로 해소하는
/// index store를 DerivedData에서 자동 선택한다. 워크트리마다 자기 빌드가 만든 index를
/// 자연스럽게 물게 하는 것이 목적 — clean 빌드 없이, TDD로 쌓인 index를 그대로 쓴다.
public enum IndexStoreLocator {

    public static let defaultDerivedDataRoot =
        ("~/Library/Developer/Xcode/DerivedData" as NSString).expandingTildeInPath

    /// source-root의 소스를 해소하는 index provider를 열어 반환한다. 후보를 최신순으로 열어
    /// 충분히 해소되면 그 provider를 그대로 쓴다(재open 없이 analysis에 재사용) — 정상 케이스 1회 open.
    public static func locate(
        sourceRoot: String,
        libIndexStorePath: String,
        derivedDataRoot: String = defaultDerivedDataRoot
    ) throws -> IndexStoreDBProvider {
        let workspace = workspacePath(above: sourceRoot)
        var candidates = populatedDataStores(under: derivedDataRoot, matchingWorkspace: workspace)
        if candidates.isEmpty {
            candidates = populatedDataStores(under: derivedDataRoot, matchingWorkspace: nil)
        }
        guard !candidates.isEmpty else {
            throw IndexStoreLocatorError.noCandidates(derivedDataRoot: derivedDataRoot)
        }

        let samples = sampleTypeUnits(sourceRoot: sourceRoot, limit: 12)
        // 후보를 전부 열어 샘플 해소 수가 최대인 것을 채택 — 부분 stale(예: 7/12) 최신 후보를
        // 완전 해소(12/12) 후보보다 먼저 채택하던 갭을 없앤다. workspace 필터로 후보가 적어 감당 가능.
        let providers = candidates.compactMap { store -> IndexStoreDBProvider? in
            try? IndexStoreDBProvider(
                storePath: store,
                databasePath: NSTemporaryDirectory() + "cx-locate-" + UUID().uuidString,
                libIndexStorePath: libIndexStorePath
            )
        }
        let best = pickBest(providers) { provider in
            samples.filter {
                provider.definitionUSR(named: $0.name, file: $0.file, line: $0.line) != nil
            }.count
        }
        guard let best else {
            throw IndexStoreLocatorError.noResolvingStore(sourceRoot: sourceRoot, tried: candidates.count)
        }
        return best
    }

    /// 해소 수가 최대인 후보 선택(0이면 제외). 실 index 없이 선택 로직을 검증하도록 프로브를 클로저로 주입.
    static func pickBest<T>(_ candidates: [T], resolvedCount: (T) -> Int) -> T? {
        var best: (item: T, resolved: Int)?
        for candidate in candidates {
            let resolved = resolvedCount(candidate)
            if resolved > (best?.resolved ?? 0) { best = (candidate, resolved) }
        }
        guard let best, best.resolved > 0 else { return nil }
        return best.item
    }

    /// 심볼릭·/private·`..` 차이를 흡수한 경로 정규화 (workspace 등가 비교용).
    private static func normalized(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    // MARK: - DerivedData 열거

    /// `<root>/*/Index.noindex/DataStore` 중 populated인 것을 **최신 빌드순(DataStore mtime desc)**으로.
    /// workspace 지정 시 info.plist로 현재 워크트리 것만 남긴다.
    static func populatedDataStores(under root: String, matchingWorkspace workspace: String?) -> [String] {
        let dirs = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
        let stores = dirs.compactMap { dir -> (path: String, mtime: Date)? in
            let ddPath = root + "/" + dir
            let store = ddPath + "/Index.noindex/DataStore"
            guard (try? IndexStoreDBProvider.assertPopulated(storePath: store)) != nil else { return nil }
            if let workspace {
                // 심볼릭·/private 차이를 흡수해 비교 — 한쪽만 정규화하면 워크트리 매핑이 조용히 깨진다.
                guard let ddWorkspace = self.workspace(ofDerivedData: ddPath),
                      normalized(ddWorkspace) == normalized(workspace)
                else { return nil }
            }
            let mtime = (try? FileManager.default.attributesOfItem(atPath: store)[.modificationDate] as? Date) ?? nil
            return (store, mtime ?? .distantPast)
        }
        return stores.sorted { $0.mtime > $1.mtime }.map { $0.path }
    }

    /// DerivedData의 info.plist가 기록한 WorkspacePath.
    static func workspace(ofDerivedData ddPath: String) -> String? {
        guard let dict = NSDictionary(contentsOfFile: ddPath + "/info.plist"),
              let path = dict["WorkspacePath"] as? String
        else { return nil }
        return path
    }

    // MARK: - source-root 기반 워크스페이스 추정

    /// source-root에서 상위로 올라가며 `.xcworkspace`를 담은 첫 디렉토리의 워크스페이스 경로.
    static func workspacePath(above sourceRoot: String) -> String? {
        var dir = (sourceRoot as NSString).standardizingPath
        while dir != "/" && !dir.isEmpty {
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
            if let ws = entries.first(where: { $0.hasSuffix(".xcworkspace") }) {
                return dir + "/" + ws
            }
            dir = (dir as NSString).deletingLastPathComponent
        }
        return nil
    }

    // MARK: - 샘플 타입 수집

    /// source-root의 앞쪽 파일을 스캔해 타입 유닛 이름/위치 샘플을 모은다(해소율 프로브용).
    static func sampleTypeUnits(sourceRoot: String, limit: Int) -> [(name: String, file: String, line: Int)] {
        let files = SwiftFileEnumerator.files(under: sourceRoot, scope: .whole)
        var samples: [(name: String, file: String, line: Int)] = []
        for file in files {
            guard let source = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            for unit in SyntaxScanner().scan(source: source, file: file) where unit.kind == .type {
                samples.append((unit.name, unit.file, unit.line))
                if samples.count >= limit { return samples }
            }
        }
        return samples
    }
}
