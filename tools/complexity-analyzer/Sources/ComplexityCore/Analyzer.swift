import Foundation

/// 페이즈 1 오케스트레이션 — 파일 스캔 → 측정(내부 복잡도·fan-in) → scope 필터.
/// 총점·가중 합성은 후속 페이즈(5).
public struct Analyzer {

    private let index: any IndexProviding
    private let scanner: SyntaxScanner

    public init(index: any IndexProviding, scanner: SyntaxScanner = SyntaxScanner()) {
        self.index = index
        self.scanner = scanner
    }

    public func analyze(sourceRoot: String, scope: Scope) throws -> [AnalyzedUnit] {
        let files = SwiftFileEnumerator.files(under: sourceRoot, scope: scope)
        let fanIn = FanIn(index: index)

        let units = files.flatMap { file -> [AnalyzedUnit] in
            guard let source = try? String(contentsOfFile: file, encoding: .utf8) else { return [] }
            return scanner.scan(source: source, file: file).map { unit in
                var withFanIn = unit
                switch unit.kind {
                case .type:
                    withFanIn.measurements.fanIn =
                        fanIn.directCount(name: unit.name, file: file, line: unit.line)
                case .method:
                    withFanIn.measurements.fanInByHop =
                        fanIn.byHop(name: unit.name, file: file, line: unit.line, maxHop: 2)
                }
                return withFanIn
            }
        }

        return units.filter { scope.includes($0) }
    }
}
