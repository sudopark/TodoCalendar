import Testing
@testable import ComplexityCore

@Suite("Analyzer 부트스트랩")
struct AnalyzerBootstrapTests {

    @Test("파이프라인이 도는지 — 부트스트랩 골격")
    func runsPipeline() {
        let result = Analyzer().run(
            sourceRoot: ".",
            indexStorePath: "/tmp",
            scope: "whole"
        )
        #expect(result == "ok")
    }
}
