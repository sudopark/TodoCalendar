import Foundation
import ArgumentParser
import ComplexityCore

@main
struct ComplexityAnalyzerCLI: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "complexity-analyzer",
        abstract: "TodoCalendar 구조 복잡도 분석기 (메소드: 내부복잡도·CQS·Combine 역할혼합·fan-in / 타입: 응집·표면적·롤업·fan-in·협업그래프[fan-out·cycle·체인깊이·blast])"
    )

    @Option(name: .customLong("source-root"), help: "분석할 소스 루트 경로")
    var sourceRoot: String

    @Option(name: .customLong("index-store-path"), help: "IndexStore DataStore 경로")
    var indexStorePath: String

    @Option(name: .customLong("scope"), help: "분석 범위 (whole | file:<경로> | type:<이름>)")
    var scope: String = "whole"

    @Option(name: .customLong("lib-index-store"), help: "libIndexStore.dylib 경로")
    var libIndexStore: String =
        "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"

    @Option(name: .customLong("config"), help: "스코어링 config JSON 경로 (생략 시 기본 가중치, 일부 필드만 줘도 나머지는 기본값)")
    var configPath: String?

    func run() async throws {
        let index = try IndexStoreDBProvider(
            storePath: indexStorePath,
            databasePath: NSTemporaryDirectory() + "cx-idx-" + UUID().uuidString,
            libIndexStorePath: libIndexStore
        )
        let config: ScoringConfig
        if let configPath {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            config = try JSONDecoder().decode(ScoringConfig.self, from: data)
        } else {
            config = .default
        }
        let units = try Analyzer(index: index, config: config).analyze(
            sourceRoot: sourceRoot,
            scope: Scope.parse(scope)
        )
        print(try JSONReporter().string(for: units))
    }
}
