//
//  EventNotificationSettingUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest

@testable import Domain


class EventNotificationSettingUsecaseImpleTests: XCTestCase {
    
    private func makeUsecase() -> EventNotificationSettingUsecaseImple {
        return .init()
    }
}


extension EventNotificationSettingUsecaseImpleTests {
    
    func testUsecase_provideNotificationTimeOptionsForAllDay() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let options = usecase.availableTimes(forAllDay: true)
        
        // then
        XCTAssertEqual(options, [
            .allDay9AM,
            .allDay12AM,
            .allDay9AMBefore(seconds: 3600.0*24),
            .allDay9AMBefore(seconds: 3600.0*24*2),
            .allDay9AMBefore(seconds: 3600.0*24*7)
        ])
    }
    
    func testUsecase_provideNotificationTimeOptionsForNotAllDay() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let options = usecase.availableTimes(forAllDay: false)
        
        // then
        XCTAssertEqual(options, [
            .atTime,
            .before(seconds: 60.0),
            .before(seconds: 60.0*5),
            .before(seconds: 60.0*10),
            .before(seconds: 60.0*15),
            .before(seconds: 60.0*30),
            .before(seconds: 60.0*60),
            .before(seconds: 60.0*120),
            .before(seconds: 3600.0*24),
            .before(seconds: 3600.0*24*2),
            .before(seconds: 3600.0*24*7)
        ])
    }
}
