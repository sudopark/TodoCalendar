//
//  E2ETestCase.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import XCTest


class E2ETestCase: XCTestCase {
    
    private enum Constant {
        static let holidayPath: String = "/v2/holiday"
        static let stubTimeout: TimeInterval = 30
    }
    
    private(set) var stubServer: StubHTTPServer!
    private(set) var coldLaunchHolidayName: String!
    private var stubServerPort: Int!
    private var didLaunchApp: Bool = false
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.continueAfterFailure = false
        self.stubServer = StubHTTPServer()
        self.stubServerPort = try self.stubServer.start()
        self.registerColdLaunchResponses()
    }
    
    override func tearDown() {
        self.assertColdLaunchResponsesConsumed()
        self.stubServer.stop()
        self.stubServer = nil
        self.stubServerPort = nil
        self.coldLaunchHolidayName = nil
        self.didLaunchApp = false
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
        self.didLaunchApp = true
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

// MARK: - 콜드런치 응답 세트

extension E2ETestCase {
    
    // 콜드런치가 무엇을 부르는지는 시나리오가 아니라 여기 한 곳이 안다
    private func registerColdLaunchResponses() {
        // 이름이 실행마다 달라야 캐시로 초록이 나는 것을 구분한다
        self.coldLaunchHolidayName = "e2e-holiday-\(UUID().uuidString.prefix(8))"
        self.stubServer.register(
            path: Constant.holidayPath,
            json: E2EFixture().holidaysJSON(named: self.coldLaunchHolidayName, on: Date())
        )
    }
    
    private func assertColdLaunchResponsesConsumed() {
        guard self.didLaunchApp else { return }
        
        self.waitStubReceives(path: Constant.holidayPath, timeout: Constant.stubTimeout)
        XCTAssertEqual(self.stubServer.unhandledRequestPaths, [])
    }
}
