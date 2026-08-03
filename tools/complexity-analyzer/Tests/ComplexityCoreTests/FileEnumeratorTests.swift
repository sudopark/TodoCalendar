import Testing
import Foundation
@testable import ComplexityCore

@Suite("파일 열거 — 테스트 코드 제외")
struct FileEnumeratorTests {

    @Test("테스트 경로/타겟·더블 접두·Tests 접미는 테스트 코드")
    func identifiesTestCode() {
        #expect(SwiftFileEnumerator.isTestCode("/p/Domain/Tests/Usecases/FooUsecaseImpleTests.swift"))
        #expect(SwiftFileEnumerator.isTestCode("/p/Supports/TestDoubles/StubTodoRepo.swift"))
        #expect(SwiftFileEnumerator.isTestCode("/p/Supports/UnitTestHelpKit/BaseTestCase.swift"))
        #expect(SwiftFileEnumerator.isTestCode("/p/Domain/Sources/StubEventLoader.swift"))   // 접두 Stub
        #expect(SwiftFileEnumerator.isTestCode("/p/x/SpyRouter.swift"))
        #expect(SwiftFileEnumerator.isTestCode("/p/x/FooTests.swift"))                        // 접미 Tests
    }

    @Test("production 소스는 테스트 코드 아님")
    func productionIsNotTestCode() {
        #expect(!SwiftFileEnumerator.isTestCode("/p/Domain/Sources/Models/Events/TodoEvent.swift"))
        #expect(!SwiftFileEnumerator.isTestCode("/p/Domain/Sources/Usecases/EventTagUsecase.swift"))
    }

    @Test("스냅샷 디렉토리는 테스트 코드")
    func snapshotsIsTestCode() {
        #expect(SwiftFileEnumerator.isTestCode("/p/Presentations/CalendarScenes/Snapshots/CalendarScenesSnapshots.swift"))
    }

    @Test("Dummy/Fake/Stub/Spy/Mock 타입명은 테스트 더블")
    func identifiesTestDoubleTypeName() {
        #expect(SwiftFileEnumerator.isTestDoubleName("DummyMonthViewModel"))
        #expect(SwiftFileEnumerator.isTestDoubleName("FakeDayEventListViewModel"))
        #expect(SwiftFileEnumerator.isTestDoubleName("StubTodoRepository"))
        #expect(!SwiftFileEnumerator.isTestDoubleName("TodoEvent"))
        #expect(!SwiftFileEnumerator.isTestDoubleName("EventDetailRouter"))
    }

    @Test("열거는 production만 남기고 테스트 파일을 제외한다")
    func enumerationExcludesTestFiles() throws {
        let dir = NSTemporaryDirectory() + "cx-enum-" + UUID().uuidString
        let sub = dir + "/Tests"
        try FileManager.default.createDirectory(atPath: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }
        try "struct A {}".write(toFile: dir + "/A.swift", atomically: true, encoding: .utf8)
        try "struct StubB {}".write(toFile: dir + "/StubB.swift", atomically: true, encoding: .utf8)
        try "struct C {}".write(toFile: dir + "/CTests.swift", atomically: true, encoding: .utf8)
        try "struct D {}".write(toFile: sub + "/D.swift", atomically: true, encoding: .utf8)

        let files = SwiftFileEnumerator.files(under: dir, scope: .whole)
        #expect(files.contains { $0.hasSuffix("/A.swift") })
        #expect(!files.contains { $0.hasSuffix("/StubB.swift") })   // 더블 접두
        #expect(!files.contains { $0.hasSuffix("/CTests.swift") })  // Tests 접미
        #expect(!files.contains { $0.contains("/Tests/") })          // 테스트 경로
    }
}
