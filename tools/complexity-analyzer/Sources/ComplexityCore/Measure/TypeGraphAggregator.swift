/// 타입 유닛을 정확 USR로 해소해 전역 의존 그래프를 만들고,
/// 협업 raw 측정(fan-out·cycle 크기·chain depth·blast radius)을 타입 유닛에 패치한다.
/// 그래프는 whole-scope로 만들고(엣지가 scope를 넘나듦) 필터는 상류(Analyzer)에서.
enum TypeGraphAggregator {

    static func patched(
        units: [AnalyzedUnit],
        index: any IndexProviding,
        maxBlastHop: Int
    ) -> [AnalyzedUnit] {
        var result = units

        // 타입 유닛 → 정확 USR. usr → result 인덱스.
        var indexByUSR: [String: Int] = [:]
        for (i, unit) in result.enumerated() where unit.kind == .type {
            guard let usr = index.definitionUSR(named: unit.name, file: unit.file, line: unit.line)
            else { continue }
            indexByUSR[usr] = i
        }
        let knownUSRs = Set(indexByUSR.keys)
        guard !knownUSRs.isEmpty else { return result }

        // 엣지 수집: 각 타입 B의 참조 → caller → enclosing 타입 A. A∈known, A≠B.
        var enclosingMemo: [String: String?] = [:]
        var edges: [TypeDependencyGraph.Edge] = []
        for usrB in knownUSRs {
            for site in index.references(toUSR: usrB) {
                for caller in site.callerUSRs {
                    let usrA: String?
                    if let cached = enclosingMemo[caller] {
                        usrA = cached
                    } else {
                        let resolved = index.enclosingTypeUSR(of: caller)
                        enclosingMemo[caller] = resolved
                        usrA = resolved
                    }
                    guard let a = usrA, a != usrB, knownUSRs.contains(a) else { continue }
                    edges.append(.init(from: a, to: usrB))
                }
            }
        }

        let graph = TypeDependencyGraph(nodes: knownUSRs, edges: edges)
        let measures = graph.measures(maxBlastHop: maxBlastHop)
        for (usr, i) in indexByUSR {
            guard let m = measures[usr] else { continue }
            result[i].measurements.fanOut = m.fanOut
            result[i].measurements.dependencyCycleSize = m.cycleSize
            result[i].measurements.collaborationChainDepth = m.chainDepth
            result[i].measurements.blastRadiusByHop = m.blastByHop
        }
        return result
    }
}
