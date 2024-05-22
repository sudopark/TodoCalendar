//
//  CalendarSettingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/03.
//

import XCTest
import Combine
import UnitTestHelpKit
import Extensions
import TestDoubles

@testable import Domain


class CalendarSettingUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
    }
    
    private func makeUsecase(
        savedTimeZone: TimeZone? = nil,
        savedFirstWeekDay: DayOfWeeks? = nil
    ) -> CalendarSettingUsecaseImple {
        
        let repository = StubCalendarSettingRepository()
        if let timeZone = savedTimeZone {
            repository.saveTimeZone(timeZone)
        }
        if let savedFirstWeekDay {
            repository.saveFirstWeekDay(savedFirstWeekDay)
        }
        
        let dataStore = SharedDataStore()
        
        return CalendarSettingUsecaseImple(
            settingRepository: repository,
            shareDataStore: dataStore
        )
    }
}


extension CalendarSettingUsecaseImpleTests {
        
    func testUsecase_whenPrepare_startWithSavedTimeZone() {
        // given
        let expect = expectation(description: "timezone 정보 구독시에 저장되어있는 정보 같이 구독")
        let usecase = self.makeUsecase(savedTimeZone: TimeZone(abbreviation: "KST"))
        
        // when
        let timeZones = self.waitOutputs(expect, for: usecase.currentTimeZone) {
            usecase.prepare()
        }
        
        // then
        XCTAssertEqual(timeZones, [
            TimeZone(abbreviation: "KST")
        ])
    }
    
    func testUsecase_whenAfterSeleectTimeZone_updateCurrentTimeZone() {
        // given
        let expect = expectation(description: "timezone 선택 이후에 현재 timezone 정보 업데이트")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(savedTimeZone: TimeZone(abbreviation: "KST"))
        
        // when
        let timeZones = self.waitOutputs(expect, for: usecase.currentTimeZone) {
            usecase.prepare()
            usecase.selectTimeZone(TimeZone(abbreviation: "UTC")!)
        }
            
        // then
        XCTAssertEqual(timeZones, [
            TimeZone(abbreviation: "KST"),
            TimeZone(abbreviation: "UTC")
        ])
    }
}

extension CalendarSettingUsecaseImpleTests {
    
    func testUsecase_whenPrepareAndSaveCurrentTimeZoneNotExists_startWithSundayDefaultValue() {
        // given
        let expect = expectation(description: "저장된 주 시작요일 없는데 구독된 경우 월요일로 방출")
        let usecase = self.makeUsecase(savedFirstWeekDay: nil)
        
        // when
        let day = self.waitFirstOutput(expect, for: usecase.firstWeekDay) {
            usecase.prepare()
        }
        
        // then
        XCTAssertEqual(day, .sunday)
    }
    
    func testUsecase_whenPrepareAndSaveCurrentTimeZoneExists_updateCurrentValue() {
        // given
        let expect = expectation(description: "주 요일 시작일 구독 이후에 변경")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(savedFirstWeekDay: .friday)
        
        // when
        let days = self.waitOutputs(expect, for: usecase.firstWeekDay) {
            usecase.prepare()
            usecase.updateFirstWeekDay(.saturday)
        }
        
        // then
        XCTAssertEqual(days, [.friday, .saturday])
    }
}
