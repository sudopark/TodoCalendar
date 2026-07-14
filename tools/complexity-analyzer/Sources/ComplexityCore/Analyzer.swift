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

        // 파일별 유닛(fan-in 부착) + 정규화 타입별 facts 수집. 객체 측정은 facts를 파일 간
        // 병합한 뒤 whole-scope에서 계산해야 cross-file extension이 원본 타입에 재조립된다.
        var units: [AnalyzedUnit] = []
        var factsByQualified: [String: TypeFacts] = [:]

        for file in files {
            guard let source = try? String(contentsOfFile: file, encoding: .utf8) else { continue }
            let (fileUnits, fileFacts) = scanner.unitsAndFacts(source: source, file: file)

            units += fileUnits.map { unit in
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

            for (qualified, facts) in fileFacts {
                factsByQualified[qualified] =
                    factsByQualified[qualified].map { TypeFacts.merged($0, facts) } ?? facts
            }
        }

        let patched = ObjectMetricsAggregator.patched(units: units, factsByQualified: factsByQualified)
        return patched.filter { scope.includes($0) }
    }
}
