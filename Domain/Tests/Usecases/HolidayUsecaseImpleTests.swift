//
//  HolidayUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/06/10.
//

import XCTest
import Combine
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class HolidayUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRepository: StubHolidayRepository!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
    }
    
    private func makeUsecase(
        withCurrentLocale: String = "kr",
        latestSelectedCountryCode: String? = nil
    ) -> HolidayUsecaseImple {
        let store = SharedDataStore(serialEventQeueu: nil)
        let provider = StubLocalProvider(code: withCurrentLocale)
        let country = latestSelectedCountryCode.map {
            HolidaySupportCountry(regionCode: "kr", code: $0, name: $0)
        }
        self.stubRepository.stubCurrentCountry = country
        
        return HolidayUsecaseImple(
            holidayRepository: self.stubRepository,
            dataStore: store,
            localeProvider: provider
        )
    }
}

// MARK: - test prepare

extension HolidayUsecaseImpleTests {
    
    func testUsecase_whenWitLatestSelectedCountry_updateCurrentCountry() {
        // given
        let expect = expectation(description: "prepare 시에 저장된 국가 있으면 현재국가 업데이트됨")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(latestSelectedCountryCode: "US")
        
        // when
        let currents = self.waitOutputs(expect, for: usecase.currentSelectedCountry) {
            Task {
                try await usecase.prepare()
            }
        }
        
        // then
        XCTAssertEqual(currents.map { $0?.code }, [nil, "US"])
    }
    
    func testUsecase_whenWithoutLatestSelectedCountry_updateCurrentCountryFromCurrentLocale() async {
        // given
        let expect = expectation(description: "prepare 시에 저장된 국가 없으면 현재 locale 기준으로 현재국가 업데이트함 + 로컬에 저장")
        let usecase = self.makeUsecase(withCurrentLocale: "kr", latestSelectedCountryCode: nil)
        
        // when
        let current = self.waitFirstOutput(expect, for: usecase.currentSelectedCountry.compactMap { $0 }) {
            Task {
                try await usecase.prepare()
            }
        }
        
        // then
        XCTAssertEqual(current?.code, "kr")
        
        let saved = try? await self.stubRepository.loadLatestSelectedCountry()
        XCTAssertEqual(saved?.code, "kr")
    }
    
    func testUsecase_whenWithoutLatestSelectedCountryAndCurrentLocaleIsNotSupport_currentCountryIsNotProvided() {
        // given
        let expect = expectation(description: "prepare 시에 저장된 국가 없고 현재 locale도 지원하지 않으면 현재국가 업데이트 안함")
        let usecase = self.makeUsecase(withCurrentLocale: "not_support", latestSelectedCountryCode: nil)
        
        // when
        let current = self.waitFirstOutput(expect, for: usecase.currentSelectedCountry) {
            Task {
                try await usecase.prepare()
            }
        } ?? nil
        
        // then
        XCTAssertNil(current)
    }
}

// MARK: - test select country

extension HolidayUsecaseImpleTests {
    
    func testUsecase_udpateAvailableCountriesAndRefresh() {
        // given
        let expect = expectation(description: "선택가능 국가 목록 조회 및 refresh")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(latestSelectedCountryCode: nil)
        
        // when
        let countryLists = self.waitOutputs(expect, for: usecase.availableCountries) {
            Task {
                try await usecase.prepare()
                try await usecase.refreshAvailableCountries()
            }
        }
        
        // then
        XCTAssertEqual(countryLists.count, 2)
    }
    
    func testUsecase_whenAfterSelectCountry_udpateCurrentCountry() {
        // given
        let expect = expectation(description: "선택국가 변경시에 선택국가 업데이트됨")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecase(latestSelectedCountryCode: "kr")
        
        // when
        let countries = self.waitOutputs(expect, for: usecase.currentSelectedCountry) {
            Task {
                try await usecase.prepare()
                try await usecase.selectCountry(.init(regionCode: "us", code: "us", name: "USA"))
            }
        }
        
        // then
        XCTAssertEqual(countries.map { $0?.code }, [nil, "kr", "us"])
    }
}

// MARK: - test holiday

extension HolidayUsecaseImpleTests {
    
    func testUsecase_provideCurrentSelectedCountryHolidays() {
        // given
        let expect = expectation(description: "마지막에 저장했던 국가 기준으로 현재 년도 국경일 제공")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(latestSelectedCountryCode: "kr")
        
        // when
        let holidayss = self.waitOutputs(expect, for: usecase.holidays()) {
            Task {
                try await usecase.prepare()
                try await usecase.refreshHolidays(2023)
            }
        }
        
        // then
        XCTAssertEqual(holidayss, [
            [:],
            [ 2023: [.init(dateString: "2023", name: "kr")] ]
        ])
    }
    
    func testUsecase_whenYearChanged_provideHolidays() {
        // given
        let expect = expectation(description: "조회 년도 변경시에 국경일 정보 추가해서 제공")
        expect.expectedFulfillmentCount = 3
        let usecase = self.makeUsecase(latestSelectedCountryCode: "kr")
        
        // when
        let holidayMaps = self.waitOutputs(expect, for: usecase.holidays()) {
            Task {
                try await usecase.prepare()
                try await usecase.refreshHolidays(2023)
                try await usecase.refreshHolidays(2022)
            }
        }
        
        // then
        XCTAssertEqual(holidayMaps, [
            [:],
            [
                2023: [.init(dateString: "2023", name: "kr")]
            ],
            [
                2022: [.init(dateString: "2022", name: "kr")],
                2023: [.init(dateString: "2023", name: "kr")]
            ]
        ])
    }
    
    func testUsecase_whenCountryChanged_provideChangedCountryHoliday() {
        // given
        let expect = expectation(description: "국가 변경시에 변경된 국가의 현재 년도 국경일 제공")
        expect.expectedFulfillmentCount = 4
        let usecase = self.makeUsecase(latestSelectedCountryCode: "kr")
        
        // when
        let holidayMaps = self.waitOutputs(expect, for: usecase.holidays()) {
            Task {
                try await usecase.prepare()
                // 최초 kr 공휴일 로드됨
                try await usecase.refreshHolidays(2023)
                
                // 이후 us 이벤트 나옴
                try await usecase.selectCountry(.init(regionCode: "us", code: "us", name: "USA"))

                // kr 이벤트 나옴
                try await usecase.selectCountry(.init(regionCode: "kr", code: "kr", name: "Korea"))
            }
        }
        
        // then
        XCTAssertEqual(holidayMaps, [
            [:],
            
            [2023: [.init(dateString: "2023", name: "kr")]],
            
            [2023: [.init(dateString: "2023", name: "us")]],
            
            [2023: [.init(dateString: "2023", name: "kr")]],
        ])
    }
    
    func testUsecase_whenSelectOtherCountry_loadAllHolidaysForCurrentPreparedYears() {
        // given
        let expect = expectation(description: "국가변경시에 현재 로드되었던 년도에 해당하는 공휴일 모두 로드")
        expect.expectedFulfillmentCount = 4
        let usecase = self.makeUsecase(latestSelectedCountryCode: "kr")
        
        // when
        let holidayMap = self.waitOutputs(expect, for: usecase.holidays()) {
            Task {
                try await usecase.prepare()
                try await usecase.refreshHolidays(2023)    // 2023 공휴일 준비
                try await usecase.refreshHolidays(2022)    // 2022, 2023 공휴일 준비
                
                try await usecase.selectCountry(.init(regionCode: "en", code: "us", name: "USA")) // 이후 us 이벤트 방출
            }
        }
        
        // then
        XCTAssertEqual(holidayMap, [
            [:],
            [
                2023: [.init(dateString: "2023", name: "kr")]
            ],
            
            [
                2023: [.init(dateString: "2023", name: "kr")],
                2022: [.init(dateString: "2022", name: "kr")]
            ],
            
            [
                2023: [.init(dateString: "2023", name: "us")],
                2022: [.init(dateString: "2022", name: "us")]
            ],
        ])
    }
    
    func testUsecase_refreshHolidays() {
        // given
        let expect = expectation(description: "현재 공휴일 refresh")
        let usecase = self.makeUsecase(latestSelectedCountryCode: "kr")
        expect.expectedFulfillmentCount = 3
        
        // when
        let holidayMap = self.waitOutputs(expect, for: usecase.holidays()) {
            Task {
                try await usecase.prepare()
                try await usecase.refreshHolidays(2023)
                
                try await usecase.refreshHolidays()
            }
        }
        
        // then
        XCTAssertEqual(holidayMap, [
            [:],
            [2023: [.init(dateString: "2023", name: "kr")]],
            [2023: [.init(dateString: "2023", name: "kr-v2")]]
        ])
    }
    
    func testUsecase_loadHolidays() async throws {
        // given
        let usecase = self.makeUsecase()
        try await usecase.prepare()
        
        // when
        let holidays = try await usecase.loadHolidays(2023)
        
        // then
        XCTAssertEqual(holidays.count, 1)
        XCTAssertEqual(holidays.first?.dateString, "2023")
    }
    
    func testUsecase_whenCurrenctCountryNotPrepared_loadHolidaysFail() async {
        // given
        let usecase = self.makeUsecase()
        
        // when + then
        do {
            let _ = try await usecase.loadHolidays(2023)
            XCTFail("should fail")
        } catch {
            XCTAssert(true)
        }
    }
}

extension HolidayUsecaseImpleTests {
    
    private class StubLocalProvider: LocaleProvider {
        private let code: String?
        init(code: String?) {
            self.code = code
        }
        
        func currentRegionCode() -> String? {
            return self.code
        }
        
        func currentLocaleIdentifier() -> String {
            return "ko"
        }
    }
}
