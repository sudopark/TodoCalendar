/// index 접근 seam — fan-in 로직을 실 IndexStoreDB 없이 테스트하기 위한 추상.

/// 한 참조 지점 — 그 참조를 감싸는(호출/포함하는) caller 심볼들의 USR.
public struct ReferenceSite: Equatable, Sendable {
    public let callerUSRs: [String]
    public init(callerUSRs: [String]) {
        self.callerUSRs = callerUSRs
    }
}

public protocol IndexProviding {
    /// `(name, file, line)`에 정의된 심볼의 정확한 USR. 동명이인 방지(bare-name 전역 조회 X).
    func definitionUSR(named name: String, file: String, line: Int) -> String?
    /// 이 USR을 참조하는 지점들. 각 지점은 자신을 감싸는 caller USR을 함께 담는다.
    func references(toUSR usr: String) -> [ReferenceSite]
}
