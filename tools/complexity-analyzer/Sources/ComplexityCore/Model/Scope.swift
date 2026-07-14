/// 분석 범위 — 어떤 파일을 스캔하고 어떤 단위를 출력할지.
public enum Scope: Equatable {
    case whole
    case file(String)
    case type(String)

    /// `whole` | `file:<경로>` | `type:<이름>`
    public static func parse(_ raw: String) -> Scope {
        if raw.hasPrefix("file:") { return .file(String(raw.dropFirst("file:".count))) }
        if raw.hasPrefix("type:") { return .type(String(raw.dropFirst("type:".count))) }
        return .whole
    }

    func includes(_ unit: AnalyzedUnit) -> Bool {
        switch self {
        case .whole:
            return true
        case .file(let path):
            return unit.file == path || unit.file.hasSuffix(path)
        case .type(let name):
            return (unit.kind == .type && unit.name == name)
                || (unit.kind == .method && unit.enclosingType == name)
        }
    }
}
