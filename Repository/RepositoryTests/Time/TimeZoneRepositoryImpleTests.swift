//
//  TimeZoneRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/06/04.
//

import XCTest
import UnitTestHelpKit

@testable import Repository


class TimeZoneRepositoryImpleTests: BaseTestCase {
    
    override func setUpWithError() throws { }
    
    override func tearDownWithError() throws { }
    
    private func makeRepository() -> TimeZoneRepositoryImple {
        
        let storage = FakeEnvironmentStorage()
        return .init(environmentStorage: storage)
    }
}

extension TimeZoneRepositoryImpleTests {
    
    func testRepository_saveAndLoadTimeZone() {
        // given
        let repository = self.makeRepository()
        
        // when
        repository.saveTimeZone(TimeZone(abbreviation: "KST")!)
        let timeZone = repository.loadUserSelectedTImeZone()
        
        // then
        XCTAssertEqual(timeZone, TimeZone(abbreviation: "KST"))
    }
}
