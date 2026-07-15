/// 타입 의존 그래프 — 노드 = 타입 USR, 엣지 A→B = "A가 B를 의존".
/// raw 협업 측정(fan-out·cycle 크기·chain depth·blast radius)만 파생. 판정·가중은 페이즈 5.
struct TypeDependencyGraph {

    struct Edge: Equatable {
        let from: String
        let to: String
        init(from: String, to: String) {
            self.from = from
            self.to = to
        }
    }

    struct Measures: Equatable {
        var fanOut: Int
        var cycleSize: Int
        var chainDepth: Int
        var blastByHop: [Int]
    }

    let nodes: Set<String>
    private let outEdges: [String: Set<String>]
    private let inEdges: [String: Set<String>]

    init(nodes: Set<String>, edges: [Edge]) {
        self.nodes = nodes
        var out: [String: Set<String>] = [:]
        var inc: [String: Set<String>] = [:]
        for e in edges where e.from != e.to {
            out[e.from, default: []].insert(e.to)
            inc[e.to, default: []].insert(e.from)
        }
        self.outEdges = out
        self.inEdges = inc
    }

    /// 모든 노드의 raw 측정.
    func measures(maxBlastHop: Int) -> [String: Measures] {
        let scc = computeSCC()
        let chains = chainDepths(sccIdOf: scc.idOf)
        var result: [String: Measures] = [:]
        for node in nodes {
            result[node] = Measures(
                fanOut: outEdges[node]?.count ?? 0,
                cycleSize: scc.sizeOf[node] ?? 1,
                chainDepth: chains[node] ?? 1,
                blastByHop: blastByHop(of: node, maxHop: maxBlastHop)
            )
        }
        return result
    }

    // MARK: - blast radius (역방향 per-hop 전이 의존자, 홉별 새 노드만)

    private func blastByHop(of node: String, maxHop: Int) -> [Int] {
        var counts: [Int] = []
        var visited: Set<String> = [node]
        var frontier: Set<String> = [node]
        for hop in 0...maxHop {
            var next: Set<String> = []
            for f in frontier {
                for dep in inEdges[f] ?? [] where !visited.contains(dep) {
                    visited.insert(dep)
                    next.insert(dep)
                }
            }
            counts.append(next.count)
            if next.isEmpty {
                counts.append(contentsOf: Array(repeating: 0, count: maxHop - hop))
                break
            }
            frontier = next
        }
        return counts
    }

    // MARK: - chain depth (SCC 응축 DAG의 최장 경로 = 구별되는 의존 층 수)
    //
    // 사이클은 순수 최장경로로 정의 불가(NP·비결정)라, SCC로 응축한 DAG에서 최장 경로를 잰다.
    // DAG라 메모가 순회 순서에 무관하게 결정적. 순수 DAG면 노드 수 최장경로와 동일하고,
    // 사이클은 한 층(SCC)으로 접혀 대칭적. cycleSize가 별도로 사이클 소속을 알려준다.

    private func chainDepths(sccIdOf: [String: Int]) -> [String: Int] {
        // 응축 DAG 인접(SCC id → SCC id).
        var condensed: [Int: Set<Int>] = [:]
        for node in nodes {
            let a = sccIdOf[node]!
            for w in outEdges[node] ?? [] {
                let b = sccIdOf[w]!
                if a != b { condensed[a, default: []].insert(b) }
            }
        }
        var memo: [Int: Int] = [:]
        func depth(_ scc: Int) -> Int {
            if let cached = memo[scc] { return cached }
            let deeper = (condensed[scc] ?? []).map { depth($0) }.max() ?? 0
            let result = 1 + deeper
            memo[scc] = result
            return result
        }
        var result: [String: Int] = [:]
        for node in nodes { result[node] = depth(sccIdOf[node]!) }
        return result
    }

    // MARK: - SCC (Tarjan) → 노드별 SCC id + 크기

    private struct SCCResult {
        let idOf: [String: Int]
        let sizeOf: [String: Int]
    }

    // force unwrap은 Tarjan 불변식상 안전: 외부 루프가 nodes 전체를 방문하고, 도달 가능한
    // 노드는 재귀 진입 시 반드시 indexOf/lowlink가 먼저 채워진다.
    private func computeSCC() -> SCCResult {
        var indexOf: [String: Int] = [:]
        var lowlink: [String: Int] = [:]
        var onStack: Set<String> = []
        var stack: [String] = []
        var counter = 0
        var idOf: [String: Int] = [:]
        var sizeOf: [String: Int] = [:]
        var nextId = 0

        func strongconnect(_ v: String) {
            indexOf[v] = counter
            lowlink[v] = counter
            counter += 1
            stack.append(v)
            onStack.insert(v)
            for w in (outEdges[v] ?? []).sorted() {
                if indexOf[w] == nil {
                    strongconnect(w)
                    lowlink[v] = min(lowlink[v]!, lowlink[w]!)
                } else if onStack.contains(w) {
                    lowlink[v] = min(lowlink[v]!, indexOf[w]!)
                }
            }
            if lowlink[v] == indexOf[v] {
                var component: [String] = []
                while true {
                    let w = stack.removeLast()
                    onStack.remove(w)
                    component.append(w)
                    if w == v { break }
                }
                for m in component {
                    idOf[m] = nextId
                    sizeOf[m] = component.count
                }
                nextId += 1
            }
        }

        for v in nodes.sorted() where indexOf[v] == nil { strongconnect(v) }
        return SCCResult(idOf: idOf, sizeOf: sizeOf)
    }
}
