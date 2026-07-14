/// 타입 fan-in — 이 타입을 참조하는 cross-file 지점 수.
/// 한 타입 이름이 여러 USR로 잡힐 수 있어(오버로드·재선언) USR별 참조를 합산한다.
public struct FanIn {

    private let index: any IndexProviding

    public init(index: any IndexProviding) {
        self.index = index
    }

    public func count(forTypeNamed name: String) -> Int {
        index.typeUSRs(named: name)
            .map { index.referenceCount(ofUSR: $0) }
            .reduce(0, +)
    }
}
