//
//  CalendarSettingRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/06/04.
//

import XCTest
import UnitTestHelpKit

@testable import Repository


class CalendarSettingRepositoryImpleTests: BaseTestCase {
    
    override func setUpWithError() throws { }
    
    override func tearDownWithError() throws { }
    
    private func makeRepository() -> CalendarSettingRepositoryImple {
        
        let storage = FakeEnvironmentStorage()
        return .init(environmentStorage: storage)
    }
}

extension CalendarSettingRepositoryImpleTests {
    
    func testRepository_saveAndLoadTimeZone() {
        // given
        let repository = self.makeRepository()
        
        // when
        repository.saveTimeZone(TimeZone(abbreviation: "KST")!)
        let timeZone = repository.loadUserSelectedTImeZone()
        
        // then
        XCTAssertEqual(timeZone, TimeZone(abbreviation: "KST"))
    }
    
    func testRepository_saveAndLoadFirstWeekDay() {
        // given
        let repository = self.makeRepository()
        
        // when
        repository.saveFirstWeekDay(.wednesday)
        let weekDay = repository.firstWeekDay()
        
        // then
        XCTAssertEqual(weekDay, .wednesday)
    }
}
