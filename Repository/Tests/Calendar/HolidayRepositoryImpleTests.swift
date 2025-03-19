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


class HolidayRepositoryImpleTests: BaseLocalTests {
    
    private var spyRemote: StubRemoteAPI!
    
    override func setUpWithError() throws {
        self.fileName = "holidays"
        try super.setUpWithError()
        self.spyRemote = .init(responses: self.responses)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.spyRemote = nil
    }
    
    private func makeRepository() -> HolidayRepositoryImple {
        let storage = FakeEnvironmentStorage()
        return HolidayRepositoryImple(
            localEnvironmentStorage: storage,
            sqliteService: self.sqliteService,
            remoteAPI: self.spyRemote
        )
    }
}


// MARK: - test country

extension HolidayRepositoryImpleTests {
    
    func testRepository_loadAvailableCountries() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let countries = try? await repository.loadAvailableCountrise()
        
        // then
        let algeria = countries?.first(where: { $0.name == "Algeria" })
        XCTAssertEqual(countries?.count, 3)
        XCTAssertEqual(algeria?.code, "dz")
        XCTAssertEqual(algeria?.name, "Algeria")
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


// MARK: - test holiday

extension HolidayRepositoryImpleTests {
    
    private func makeRepositoryWithHolidayCaches(
        _ pairs: [(Int, String)]
    ) async -> HolidayRepositoryImple {
        let repository = self.makeRepository()
        await pairs.asyncForEach {
            _ = try? await repository.loadHolidays($0.0, $0.1)
        }
        self.spyRemote.didRequestedPath = nil
        return repository
    }
    
    // 캐시 없으면 리모트에서 로드
    func testRepository_loadHolidaysWithoutCache() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let holidays = try? await repository.loadHolidays(2023, "KR")
        
        // then
        XCTAssertEqual(holidays, [
            .init(dateString: "2023-01-01", localName: "새해", name: "New Year's Day")
        ])
        XCTAssertNotNil(self.spyRemote.didRequestedPath)
    }
    
    // 캐시 있으면 캐시만 반환
    func testReposiotry_loadHolidays_withCache() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([(2023, "KR")])
        
        // when
        let holidays = try? await repository.loadHolidays(2023, "KR")
        
        // then
        XCTAssertEqual(holidays, [
            .init(dateString: "2023-01-01", localName: "새해", name: "New Year's Day")
        ])
        XCTAssertNil(self.spyRemote.didRequestedPath)
    }
    
    // 캐시는 국가별로 구분
    func testRepository_loadHolidaysFromCache_byCountry() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([
            (2023, "KR"), (2023, "US")
        ])
        
        // when
        let holidaysKR = try? await repository.loadHolidays(2023, "KR")
        let holidaysUS = try? await repository.loadHolidays(2023, "US")
        
        // then
        XCTAssertEqual(holidaysKR, [
            .init(dateString: "2023-01-01", localName: "새해", name: "New Year's Day")
        ])
        XCTAssertEqual(holidaysUS, [
            .init(dateString: "2023-01-01", localName: "New Year's Day", name: "New Year's Day")
        ])
    }
    
    // 캐시는 연도별로 구분
    func testReposiotry_loadHolidaysFromCache_byYear() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([
            (2023, "KR"), (2022, "KR")
        ])
        
        // when
        let holidays2023 = try? await repository.loadHolidays(2023, "KR")
        let holidays2022 = try? await repository.loadHolidays(2022, "KR")
        
        // then
        XCTAssertEqual(holidays2023, [
            .init(dateString: "2023-01-01", localName: "새해", name: "New Year's Day")
        ])
        XCTAssertEqual(holidays2022, [
            .init(dateString: "2022-01-01", localName: "새해", name: "New Year's Day")
        ])
    }
    
    // 캐시 삭제 이후에 다시 로드
    func testRepository_loadHolidaysAfterInvalidateCache() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([(2023, "KR")])
        
        // when
        try? await repository.clearHolidayCache()
        let holidays = try? await repository.loadHolidays(2023, "KR")
        
        // then
        XCTAssertEqual(holidays, [
            .init(dateString: "2023-01-01", localName: "새해", name: "New Year's Day")
        ])
        XCTAssertNotNil(self.spyRemote.didRequestedPath)
    }
}


extension HolidayRepositoryImpleTests {
    
    private var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                endpoint: HolidayAPIEndpoints.supportCountry,
                header: [:],
                parameters: [:],
                resultJsonString: .success(
                """
                {
                  "Afghanistan": "en.af#holiday@group.v.calendar.google.com",
                  "Albania": "en.al#holiday@group.v.calendar.google.com",
                  "Algeria": "en.dz#holiday@group.v.calendar.google.com"
                }
                """
            )),
            .init(
                endpoint: HolidayAPIEndpoints.holidays(year: 2023, countryCode: "KR"),
                resultJsonString: .success(
                """
                [
                  {
                    "date": "2023-01-01",
                    "localName": "새해",
                    "name": "New Year's Day",
                    "countryCode": "KR",
                    "fixed": true,
                    "global": true,
                    "counties": null,
                    "launchYear": null,
                    "types": [
                      "Public"
                    ]
                  }
                ]
                """
            )),
            .init(
                endpoint: HolidayAPIEndpoints.holidays(year: 2022, countryCode: "KR"),
                resultJsonString: .success(
                """
                [
                  {
                    "date": "2022-01-01",
                    "localName": "새해",
                    "name": "New Year's Day",
                    "countryCode": "KR",
                    "fixed": true,
                    "global": true,
                    "counties": null,
                    "launchYear": null,
                    "types": [
                      "Public"
                    ]
                  }
                ]
                """
            )),
            .init(
                endpoint: HolidayAPIEndpoints.holidays(year: 2023, countryCode: "US"),
                resultJsonString: .success(
                """
                [
                  {
                    "date": "2023-01-01",
                    "localName": "New Year's Day",
                    "name": "New Year's Day",
                    "countryCode": "US",
                    "fixed": true,
                    "global": true,
                    "counties": null,
                    "launchYear": null,
                    "types": [
                      "Public"
                    ]
                  }
                ]
                """
            )),
        ]
    }
}
