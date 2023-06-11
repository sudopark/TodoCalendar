//
//  HolidayRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/06/11.
//

import XCTest
import Domain
import UnitTestHelpKit

@testable import Repository


class HolidayRepositoryImpleTests: BaseTestCase {
    
    private func makeRepository() -> HolidayRepositoryImple {
        let storage = FakeEnvironmentStorage()
        let remote = StubRemoteAPI(responses: self.responses)
        return HolidayRepositoryImple(localEnvironmentStorage: storage, remoteAPI: remote)
    }
}


extension HolidayRepositoryImpleTests {
    
    func testRepository_loadAvailableCountries() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let countries = try? await repository.loadAvailableCountrise()
        
        // then
        XCTAssertEqual(countries?.count, 3)
        XCTAssertEqual(countries?.first?.code, "AD")
        XCTAssertEqual(countries?.first?.name, "Andorra")
    }
    
    func testRepository_saveAndLoadLatestSelectedCountry() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let countryBeforeSave = try? await repository.loadLatestSelectedCountry()
        let newCountry = HolidaySupportCountry(code: "new", name: "new country")
        try? await repository.saveSelectedCountry(newCountry)
        let countryAfterSave = try? await repository.loadLatestSelectedCountry()
        
        // then
        XCTAssertNil(countryBeforeSave)
        XCTAssertEqual(countryAfterSave?.code, "new")
    }
}


extension HolidayRepositoryImpleTests {
    
    private var responses: [StubRemoteAPI.Resopnse] {
        return [
            .init(
                path: "https://date.nager.at/api/v3/AvailableCountries",
                resultJsonString: .success(
                """
                [
                  {
                    "countryCode": "AD",
                    "name": "Andorra"
                  },
                  {
                    "countryCode": "AL",
                    "name": "Albania"
                  },
                  {
                    "countryCode": "AR",
                    "name": "Argentina"
                  }
                ]
                """
            ))
        ]
    }
}
