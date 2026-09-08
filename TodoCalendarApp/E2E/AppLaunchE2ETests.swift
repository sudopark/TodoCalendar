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
        // when
        let app = self.launchApp()
        
        // then
        let monthGrid = app.otherElements[AccessibilityID.CalendarScene.monthGrid]
        XCTAssertTrue(monthGrid.waitForExistence(timeout: 30))
    }
}
