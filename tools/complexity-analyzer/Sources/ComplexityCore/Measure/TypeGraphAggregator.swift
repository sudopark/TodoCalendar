/// 타입 유닛을 정확 USR로 해소해 전역 의존 그래프를 만들고,
/// 협업 raw 측정(fan-out·cycle 크기·chain depth·blast radius)을 타입 유닛에 패치한다.
/// 그래프는 whole-scope로 만들고(엣지가 scope를 넘나듦) 필터는 상류(Analyzer)에서.
enum TypeGraphAggregator {

    static func patched(
        units: [AnalyzedUnit],
        index: any IndexProviding,
        maxBlastHop: Int
    ) throws -> [AnalyzedUnit] {
        var result = units

        // 타입 유닛 → 정확 USR. usr → result 인덱스.
        var indexByUSR: [String: Int] = [:]
        var typeUnitCount = 0
        for (i, unit) in result.enumerated() where unit.kind == .type {
            typeUnitCount += 1
            guard let usr = index.definitionUSR(named: unit.name, file: unit.file, line: unit.line)
            else { continue }
            indexByUSR[usr] = i
        }
        let knownUSRs = Set(indexByUSR.keys)
        // 타입 유닛이 있는데 USR 해소가 하나도 안 되면 = index가 현재 소스와 불일치(stale).
        // 협업 측정을 조용히 전부 nil로 흘리지 않도록 명시 throw. (store가 비진 않아 assertPopulated는 못 잡음)
        if typeUnitCount > 0, knownUSRs.isEmpty {
            throw IndexStoreError.staleOrMismatched(typeUnitCount: typeUnitCount)
        }
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

        // 순환(SCC 크기>1)마다 참조 타입(class/actor) 수를 세서 멤버에 부착 — 경중 등급화용.
        // 값 타입만인 순환(데이터 클러스터)은 0, 참조 타입 낀 순환은 그 수만큼 병리 가중.
        func isReferenceType(_ usr: String) -> Bool {
            guard let i = indexByUSR[usr] else { return false }
            switch result[i].typeDeclKind {
            case .class, .actor: return true
            default: return false
            }
        }
        for component in graph.stronglyConnectedComponents() where component.count > 1 {
            let referenceCount = component.filter(isReferenceType).count
            for usr in component {
                if let i = indexByUSR[usr] { result[i].measurements.cycleReferenceTypeCount = referenceCount }
            }
        }
        return result
    }
}
