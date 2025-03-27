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
        XCTAssertEqual(countries?.count, 2)
        XCTAssertEqual(countries?.first?.code, "dutch")
        XCTAssertEqual(countries?.first?.name, "Netherlands")
        XCTAssertEqual(countries?.first?.regionCode, "nl")
    }
    
    func testRepository_saveAndLoadLatestSelectedCountry() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let countryBeforeSave = try? await repository.loadLatestSelectedCountry()
        let newCountry = HolidaySupportCountry(regionCode: "nw", code: "new", name: "new country")
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
        _ pairs: [(Int, String, String)]
    ) async -> HolidayRepositoryImple {
        let repository = self.makeRepository()
        await pairs.asyncForEach {
            _ = try? await repository.loadHolidays($0.0, $0.1, $0.2)
        }
        self.spyRemote.didRequestedPath = nil
        return repository
    }
    
    // 캐시 없으면 리모트에서 로드
    func testRepository_loadHolidaysWithoutCache() async {
        // given
        let repository = self.makeRepository()
        
        // when
        let holidays = try? await repository.loadHolidays(2023, "KR", "ko")
        
        // then
        XCTAssertEqual(holidays, [
            .init(dateString: "2023-01-01", name: "새해")
        ])
        XCTAssertNotNil(self.spyRemote.didRequestedPath)
    }
    
    // 캐시 있으면 캐시만 반환
    func testReposiotry_loadHolidays_withCache() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([(2023, "KR", "ko")])
        
        // when
        let holidays = try? await repository.loadHolidays(2023, "KR", "ko")
        
        // then
        XCTAssertEqual(holidays, [
            .init(dateString: "2023-01-01", name: "새해")
        ])
        XCTAssertNil(self.spyRemote.didRequestedPath)
    }
    
    // 캐시는 국가별로 구분
    func testRepository_loadHolidaysFromCache_byCountry() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([
            (2023, "KR", "ko"), (2023, "US", "en")
        ])
        
        // when
        let holidaysKR = try? await repository.loadHolidays(2023, "KR", "ko")
        let holidaysUS = try? await repository.loadHolidays(2023, "US", "en")
        
        // then
        XCTAssertEqual(holidaysKR, [
            .init(dateString: "2023-01-01", name: "새해")
        ])
        XCTAssertEqual(holidaysUS, [
            .init(dateString: "2023-01-01", name: "New Year's Day")
        ])
    }
    
    // 캐시는 연도별로 구분
    func testReposiotry_loadHolidaysFromCache_byYear() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([
            (2023, "KR", "ko"), (2022, "KR", "ko")
        ])
        
        // when
        let holidays2023 = try? await repository.loadHolidays(2023, "KR", "ko")
        let holidays2022 = try? await repository.loadHolidays(2022, "KR", "ko")
        
        // then
        XCTAssertEqual(holidays2023, [
            .init(dateString: "2023-01-01", name: "새해")
        ])
        XCTAssertEqual(holidays2022, [
            .init(dateString: "2022-01-01", name: "새해")
        ])
    }
    
    // 캐시 삭제 이후에 다시 로드
    func testRepository_loadHolidaysAfterInvalidateCache() async {
        // given
        let repository = await self.makeRepositoryWithHolidayCaches([(2023, "KR", "ko")])
        
        // when
        try? await repository.clearHolidayCache()
        let holidays = try? await repository.loadHolidays(2023, "KR", "ko")
        
        // then
        XCTAssertEqual(holidays, [
            .init(dateString: "2023-01-01", name: "새해")
        ])
        XCTAssertNotNil(self.spyRemote.didRequestedPath)
    }
}


extension HolidayRepositoryImpleTests {
    
    private var responses: [StubRemoteAPI.Response] {
        return [
            .init(
                endpoint: HolidayAPIEndpoints.supportCountry,
                resultJsonString: .success(
                """
                [
                {
                    "code": "dutch",
                    "name": "Netherlands",
                    "regionCode": "nl"
                  },
                  {
                    "code": "vietnamese",
                    "name": "Vietnam",
                    "regionCode": "vn"
                  },
                ]
                """
            )),
            .init(
                endpoint: HolidayAPIEndpoints.holidays,
                parameterCompare: { _, req in
                    return req["year"] as? Int == 2023
                    && req["locale"] as? String == "ko"
                    && req["code"] as? String == "KR"
                },
                resultJsonString: .success(
                """
                {
                    "items": [
                      {
                        "start": {
                            "date": "2023-01-01"
                        },
                        "summary": "새해"
                      }
                    ]
                }
                """
            )),
            .init(
                endpoint: HolidayAPIEndpoints.holidays,
                parameterCompare: { _, req in
                    return req["year"] as? Int == 2022
                    && req["locale"] as? String == "ko"
                    && req["code"] as? String == "KR"
                },
                resultJsonString: .success(
                """
                {
                    "items": [
                      {
                        "start": {
                            "date": "2022-01-01"
                        },
                        "summary": "새해"
                      }
                    ]
                }
                """
            )),
            .init(
                endpoint: HolidayAPIEndpoints.holidays,
                parameterCompare: { _, req in
                    return req["year"] as? Int == 2023
                    && req["locale"] as? String == "en"
                    && req["code"] as? String == "US"
                },
                resultJsonString: .success(
                """
                {
                    "items": [
                      {
                        "start": {
                            "date": "2023-01-01"
                        },
                        "summary": "New Year's Day"
                      }
                    ]
                }
                """
            )),
        ]
    }
}
