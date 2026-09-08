//
//  AppLaunchE2ETests.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import XCTest
import Scenes


final class AppLaunchE2ETests: E2ETestCase {
    
    func test_whenColdLaunchWithStubbedHolidays_calendarGridRendersFromStub() {
        // given
        let holidayName = "e2e-holiday-\(UUID().uuidString.prefix(8))"
        self.stubServer.register(
            path: "/v2/holiday",
            json: E2EFixture().holidaysJSON(named: holidayName, on: Date())
        )
        
        // when
        let app = self.launchApp()
        
        // then
        let monthGrid = app.otherElements[AccessibilityID.CalendarScene.monthGrid]
        XCTAssertTrue(monthGrid.waitForExistence(timeout: 30))
        self.waitStubReceives(path: "/v2/holiday", timeout: 30)
    }
}
