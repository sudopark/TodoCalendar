import Foundation

/// 오케스트레이션 — 파일 스캔 → 측정(내부 복잡도·fan-in·객체·협업그래프) → scope 필터 → 채점.
/// 총점·가중 합성은 Scorer(페이즈 5).
public struct Analyzer {

    private let index: any IndexProviding
    private let scanner: SyntaxScanner
    private let config: ScoringConfig

    public init(
        index: any IndexProviding,
        scanner: SyntaxScanner = SyntaxScanner(),
        config: ScoringConfig = .default
    ) {
        self.index = index
        self.scanner = scanner
        self.config = config
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

        let objectPatched = ObjectMetricsAggregator.patched(units: units, factsByQualified: factsByQualified)
        // 협업 그래프는 whole-scope에서 빌드(엣지가 scope 경계를 넘나듦) → 부착 후 필터.
        let graphPatched = TypeGraphAggregator.patched(units: objectPatched, index: index, maxBlastHop: 2)
        // 점수는 per-unit pure라 scope 필터 후 부착(드롭될 유닛은 채점 안 함).
        return Scorer(config: config).scored(graphPatched.filter { scope.includes($0) })
    }
}
