/// fan-in — 유닛을 정확한 USR로 해소한 뒤 caller 그래프를 홉 상한까지 BFS해 per-hop 참조 수를 낸다.
/// 가중(홉별 감쇠)은 페이즈 5. 여기선 raw per-hop 카운트만.
public struct FanIn {

    private let index: any IndexProviding

    public init(index: any IndexProviding) {
        self.index = index
    }

    /// hop0(직접)부터 maxHop까지 각 홉의 참조 지점 수. 배열 길이 = maxHop+1.
    /// USR 못 찾으면 nil(측정 불가). frontier 소진 시 남은 홉은 0.
    public func byHop(name: String, file: String, line: Int, maxHop: Int) -> [Int]? {
        guard let usr = index.definitionUSR(named: name, file: file, line: line) else { return nil }

        var counts: [Int] = []
        var frontier: Set<String> = [usr]
        var visited: Set<String> = [usr]

        for hop in 0...maxHop {
            let refs = frontier.flatMap { index.references(toUSR: $0) }
            counts.append(refs.count)
            if hop == maxHop { break }

            var next: Set<String> = []
            for site in refs {
                for caller in site.callerUSRs where !visited.contains(caller) {
                    visited.insert(caller)
                    next.insert(caller)
                }
            }
            if next.isEmpty {
                counts.append(contentsOf: Array(repeating: 0, count: maxHop - hop))
                break
            }
            frontier = next
        }
        return counts
    }

    /// 직접 참조 수(hop0). type fan-in용. USR 못 찾으면 0.
    public func directCount(name: String, file: String, line: Int) -> Int {
        byHop(name: name, file: file, line: line, maxHop: 0)?.first ?? 0
    }
}
