//
//  AppLaunchE2ETests.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import XCTest


final class AppLaunchE2ETests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        self.continueAfterFailure = false
    }
    
    func test_whenLaunchAsUITestRun_appShowsRootWindow() {
        // given
        let app = XCUIApplication()
        app.launchArguments += ["-uiTest"]
        
        // when
        app.launch()
        
        // then
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 30))
    }
}
