//
//  EventNotificationSettingUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import TestDoubles

@testable import Domain


class EventNotificationSettingUsecaseImpleTests: XCTestCase {
    
    private func makeUsecase() -> EventNotificationSettingUsecaseImple {
        return .init(
            notificationRepository: StubEventNotificationRepository()
        )
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
            EventNotificationTimeOption.allDay9AM,
            EventNotificationTimeOption.allDay12AM,
            EventNotificationTimeOption.allDay9AMBefore(seconds: 3600.0*24),
            EventNotificationTimeOption.allDay9AMBefore(seconds: 3600.0*24*2),
            EventNotificationTimeOption.allDay9AMBefore(seconds: 3600.0*24*7)
        ])
    }
    
    func testUsecase_provideNotificationTimeOptionsForNotAllDay() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let options = usecase.availableTimes(forAllDay: false)
        
        // then
        XCTAssertEqual(options, [
            EventNotificationTimeOption.atTime,
            EventNotificationTimeOption.before(seconds: 60.0),
            EventNotificationTimeOption.before(seconds: 60.0*5),
            EventNotificationTimeOption.before(seconds: 60.0*10),
            EventNotificationTimeOption.before(seconds: 60.0*15),
            EventNotificationTimeOption.before(seconds: 60.0*30),
            EventNotificationTimeOption.before(seconds: 60.0*60),
            EventNotificationTimeOption.before(seconds: 60.0*120),
            EventNotificationTimeOption.before(seconds: 3600.0*24),
            EventNotificationTimeOption.before(seconds: 3600.0*24*2),
            EventNotificationTimeOption.before(seconds: 3600.0*24*7)
        ])
    }
    
    func testUsecase_saveAndLoadDefaultEventNotificationTimeOption() {
        // given
        let usecase = self.makeUsecase()
        let optionBeforeSave = usecase.loadDefailtNotificationTimeOption(forAllDay: false)
        let optionBeforeSaveFroAllDay = usecase.loadDefailtNotificationTimeOption(forAllDay: true)
        
        // when
        usecase.saveDefaultNotificationTimeOption(forAllDay: false, option: .atTime)
        usecase.saveDefaultNotificationTimeOption(forAllDay: true, option: .allDay9AMBefore(seconds: 100))
        
        // then
        let optionAfterSave = usecase.loadDefailtNotificationTimeOption(forAllDay: false)
        let optionAfterSaveForAllday = usecase.loadDefailtNotificationTimeOption(forAllDay: true)
        XCTAssertEqual(optionBeforeSave, nil)
        XCTAssertEqual(optionBeforeSaveFroAllDay, nil)
        XCTAssertEqual(optionAfterSave, .atTime)
        XCTAssertEqual(optionAfterSaveForAllday, .allDay9AMBefore(seconds: 100))
    }
}
