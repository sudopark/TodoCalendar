//
//  AppSettingRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/08/07.
//

import XCTest
import Domain
import UnitTestHelpKit

@testable import Repository


class AppSettingRepositoryImpleTests: BaseTestCase {
    
    private func makeRepository() -> AppSettingRepositoryImple {
        let storage = FakeEnvironmentStorage()
        return .init(environmentStorage: storage)
    }
}


extension AppSettingRepositoryImpleTests {
    
    func testRepository_whenSavedAppearanceNotExists_returnWithDefaultValue() {
        // given
        let repository = self.makeRepository()
        
        // when
        let appearance = repository.loadSavedViewAppearance()
        
        // then
        XCTAssertEqual(appearance.colorSetKey, .defaultLight)
        XCTAssertEqual(appearance.fontSetKey, .systemDefault)
    }
}
