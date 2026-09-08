//
//  E2ETestCase.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import XCTest


class E2ETestCase: XCTestCase {
    
    private(set) var stubServer: StubHTTPServer!
    private var stubServerPort: Int!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.continueAfterFailure = false
        self.stubServer = StubHTTPServer()
        self.stubServerPort = try self.stubServer.start()
    }
    
    override func tearDown() {
        self.stubServer.stop()
        self.stubServer = nil
        self.stubServerPort = nil
        super.tearDown()
    }
    
    func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        // 지역이 고정돼야 gist 의 지원 국가 목록과 매칭돼 홀리데이 요청이 나간다
        app.launchArguments += [
            "-uiTest",
            "-AppleLanguages", "(ko)",
            "-AppleLocale", "ko_KR"
        ]
        app.launchEnvironment["E2E_API_HOST"] = "http://127.0.0.1:\(self.stubServerPort!)"
        app.launch()
        return app
    }
    
    func waitStubReceives(path: String, timeout: TimeInterval) {
        let received = expectation(
            for: NSPredicate { [weak self] _, _ in
                self?.stubServer.handledRequestPaths.contains(path) == true
            },
            evaluatedWith: NSNull()
        )
        wait(for: [received], timeout: timeout)
    }
}
