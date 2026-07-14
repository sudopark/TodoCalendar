import ArgumentParser
import ComplexityCore

@main
struct ComplexityAnalyzerCLI: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "complexity-analyzer",
        abstract: "TodoCalendar 구조 복잡도 분석기 (페이즈 1: walking skeleton)"
    )

    @Option(name: .customLong("source-root"), help: "분석할 소스 루트 경로")
    var sourceRoot: String

    @Option(name: .customLong("index-store-path"), help: "IndexStore DataStore 경로")
    var indexStorePath: String

    @Option(name: .customLong("scope"), help: "분석 범위 (whole | file:<경로> | type:<이름>)")
    var scope: String = "whole"

    func run() async throws {
        let output = Analyzer().run(
            sourceRoot: sourceRoot,
            indexStorePath: indexStorePath,
            scope: scope
        )
        print(output)
    }
}
