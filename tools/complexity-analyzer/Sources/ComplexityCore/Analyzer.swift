import Foundation
import SwiftSyntax
import SwiftParser
import IndexStoreDB

/// 페이즈 1 walking skeleton — 파이프라인 골격만.
/// 실제 측정(내부 복잡도·fan-in)은 Task 2~4에서 채운다.
public struct Analyzer {

    public init() {}

    /// 부트스트랩: SwiftSyntax·IndexStoreDB가 링크되고 파이프라인이 도는지만 증명한다.
    public func run(sourceRoot: String, indexStorePath: String, scope: String) -> String {
        return "ok"
    }
}
