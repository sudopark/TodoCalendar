/// index 접근 seam — fan-in 로직을 실 IndexStoreDB 없이 테스트하기 위한 추상.
public protocol IndexProviding {
    /// 이 이름의 명목 타입 선언 심볼들의 USR.
    func typeUSRs(named name: String) -> [String]
    /// 이 USR을 참조하는 지점 수 (fan-in).
    func referenceCount(ofUSR usr: String) -> Int
}
