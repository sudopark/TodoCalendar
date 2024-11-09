//
//  AppSettingLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/08/07.
//

import XCTest
import Domain
import UnitTestHelpKit

@testable import Repository


class AppSettingLocalRepositoryImpleTests: BaseTestCase {
    
    private func makeRepository() -> AppSettingLocalRepositoryImple {
        let storage = AppSettingLocalStorage(environmentStorage: FakeEnvironmentStorage())
        return .init(storage: storage)
    }
}


extension AppSettingLocalRepositoryImpleTests {
    
    func testRepository_whenSavedAppearanceNotExists_returnWithDefaultValue() {
        // given
        let repository = self.makeRepository()
        
        // when
        let appearance = repository.loadSavedViewAppearance()
        
        // then
        XCTAssertEqual(appearance.calendar.colorSetKey, .systemTheme)
        XCTAssertEqual(appearance.calendar.fontSetKey, .systemDefault)
        XCTAssertEqual(appearance.calendar.showUnderLineOnEventDay, true)
        XCTAssertEqual(appearance.calendar.accnetDayPolicy, [
            .holiday: false, .sunday: false, .saturday: false
        ])
        XCTAssertEqual(appearance.calendar.showUncompletedTodos, true)
    }
}
