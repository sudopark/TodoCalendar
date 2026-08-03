/// 타입 내부 멤버 그래프에서 응집·결합 지표를 낸다(순수 함수).
/// - lcom: 메소드 그래프의 연결 요소 수(공유 프로퍼티 또는 호출로 연결). ≥2 = 분리 후보(끊김).
/// - internalCoupling: 타입 내부 메소드 호출 간선 수(과밀 — 결합).
/// - maxCallChainDepth: 내부 호출 그래프의 최장 경로 메소드 수(과밀 — 체인 깊이).

struct MethodNode: Equatable {
    let name: String
    let referencedProps: Set<String>
    let calledMethods: Set<String> // 이미 타입 내부 메소드로 교집합된 이름
    init(name: String, referencedProps: Set<String>, calledMethods: Set<String>) {
        self.name = name
        self.referencedProps = referencedProps
        self.calledMethods = calledMethods
    }
}

enum CohesionAnalyzer {

    struct Metrics: Equatable {
        var lcom: Int
        var internalCoupling: Int
        var maxCallChainDepth: Int
    }

    static func metrics(methods: [MethodNode]) -> Metrics {
        let names = Set(methods.map { $0.name })
        // 타입 내부로 한정된 인접(호출) 그래프.
        let adjacency = Dictionary(
            methods.map { ($0.name, $0.calledMethods.intersection(names)) },
            uniquingKeysWith: { a, b in a.union(b) }
        )
        return Metrics(
            lcom: lcom(methods),
            internalCoupling: adjacency.values.reduce(0) { $0 + $1.count },
            maxCallChainDepth: maxChainDepth(names: names, adjacency: adjacency)
        )
    }

    /// LCOM4 — 메소드 정점 그래프의 연결 요소 수. 간선: 공유 프로퍼티 || 호출 관계.
    private static func lcom(_ methods: [MethodNode]) -> Int {
        guard !methods.isEmpty else { return 0 }

        var parent = Array(0..<methods.count)
        func find(_ i: Int) -> Int {
            var r = i
            while parent[r] != r { parent[r] = parent[parent[r]]; r = parent[r] }
            return r
        }
        func union(_ i: Int, _ j: Int) { parent[find(i)] = find(j) }

        let nameToIndex = Dictionary(
            methods.enumerated().map { ($1.name, $0) },
            uniquingKeysWith: { a, _ in a }
        )

        for i in methods.indices {
            for j in methods.indices where j > i {
                if !methods[i].referencedProps.isDisjoint(with: methods[j].referencedProps) {
                    union(i, j)
                }
            }
            for callee in methods[i].calledMethods {
                if let j = nameToIndex[callee] { union(i, j) }
            }
        }
        return Set(methods.indices.map { find($0) }).count
    }

    /// 내부 호출 그래프의 가장 긴 경로(메소드 수). 노드별 memo로 O(V+E) —
    /// dense 그래프에서 simple-path 전수 탐색이 지수 폭발하는 것을 막는다.
    /// 사이클은 `onStack` back-edge에서 0으로 끊어 유한(DAG면 정확, 순환 그래프는 근사).
    private static func maxChainDepth(names: Set<String>, adjacency: [String: Set<String>]) -> Int {
        var memo: [String: Int] = [:]
        var onStack: Set<String> = []

        func depth(_ node: String) -> Int {
            if let cached = memo[node] { return cached }
            guard !onStack.contains(node) else { return 0 } // 사이클 back-edge
            onStack.insert(node)
            let deeper = (adjacency[node] ?? []).map { depth($0) }.max() ?? 0
            onStack.remove(node)
            let result = 1 + deeper
            memo[node] = result
            return result
        }
        return names.map { depth($0) }.max() ?? 0
    }
}
