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
        withCurrentLocale: String = "KR",
        latestSelectedCountryCode: String? = nil
    ) -> HolidayUsecaseImple {
        let store = SharedDataStore(serialEventQeueu: nil)
        let provider = StubLocalProvider(code: withCurrentLocale)
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
        let usecase = self.makeUsecase(latestSelectedCountryCode: "KR")
        
        // when
        let current = self.waitFirstOutput(expect, for: usecase.currentSelectedCountry) {
            Task {
                try await usecase.prepare()
            }
        }
        
        // then
        XCTAssertEqual(current?.code, "KR")
    }
    
    func testUsecase_whenWithoutLatestSelectedCountry_updateCurrentCountryFromCurrentLocale() async {
        // given
        let expect = expectation(description: "prepare 시에 저장된 국가 없으면 현재 locale 기준으로 현재국가 업데이트함 + 로컬에 저장")
        let usecase = self.makeUsecase(withCurrentLocale: "KR", latestSelectedCountryCode: nil)
        
        // when
        let current = self.waitFirstOutput(expect, for: usecase.currentSelectedCountry) {
            Task {
                try await usecase.prepare()
            }
        }
        
        // then
        XCTAssertEqual(current?.code, "KR")
        
        let saved = try? await self.stubRepository.loadLatestSelectedCountry()
        XCTAssertEqual(saved?.code, "KR")
    }
    
    func testUsecase_whenWithoutLatestSelectedCountryAndCurrentLocaleIsNotSupport_currentCountryIsNotProvided() {
        // given
        let expect = expectation(description: "prepare 시에 저장된 국가 없고 현재 locale도 지원하지 않으면 현재국가 업데이트 안함")
        expect.isInverted = true
        let usecase = self.makeUsecase(withCurrentLocale: "not_support", latestSelectedCountryCode: nil)
        
        // when
        let current = self.waitFirstOutput(expect, for: usecase.currentSelectedCountry) {
            Task {
                try await usecase.prepare()
            }
        }
        
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
        let usecase = self.makeUsecase(latestSelectedCountryCode: "KR")
        
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
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(latestSelectedCountryCode: "KR")
        
        // when
        let countries = self.waitOutputs(expect, for: usecase.currentSelectedCountry) {
            Task {
                try await usecase.prepare()
                try await usecase.selectCountry(.init(code: "US", name: "USA"))
            }
        }
        
        // then
        XCTAssertEqual(countries.map { $0.code }, ["KR", "US"])
    }
}

// MARK: - test holiday

extension HolidayUsecaseImpleTests {
    
    func testUsecase_provideCurrentSelectedCountryHolidays() {
        // given
        let expect = expectation(description: "마지막에 저장했던 국가 기준으로 현재 년도 국경일 제공")
        let usecase = self.makeUsecase(latestSelectedCountryCode: "KR")
        
        // when
        let holidays = self.waitFirstOutput(expect, for: usecase.holidays()) {
            Task {
                try await usecase.prepare()
                try await usecase.refreshHolidays(2023)
            }
        }
        
        // then
        XCTAssertEqual(holidays, [
            2023: [.init(dateString: "2023", localName: "KR", name: "dummy")]
        ])
    }
    
    func testUsecase_whenYearChanged_provideHolidays() {
        // given
        let expect = expectation(description: "조회 년도 변경시에 국경일 정보 추가해서 제공")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase(latestSelectedCountryCode: "KR")
        
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
            [
                2023: [.init(dateString: "2023", localName: "KR", name: "dummy")]
            ],
            [
                2022: [.init(dateString: "2022", localName: "KR", name: "dummy")],
                2023: [.init(dateString: "2023", localName: "KR", name: "dummy")]
            ]
        ])
    }
    
    func testUsecase_whenCountryChanged_provideChangedCountryHoliday() {
        // given
        let expect = expectation(description: "국가 변경시에 변경된 국가의 현재 년도 국경일 제공")
        expect.expectedFulfillmentCount = 4
        let usecase = self.makeUsecase(latestSelectedCountryCode: "KR")
        
        // when
        let holidayMaps = self.waitOutputs(expect, for: usecase.holidays()) {
            Task {
                try await usecase.prepare()
                try await usecase.refreshHolidays(2023)
                
                try await usecase.selectCountry(.init(code: "US", name: "USA"))
                try await usecase.refreshHolidays(2023)
                
                try await usecase.selectCountry(.init(code: "KR", name: "Korea"))
            }
        }
        
        // then
        XCTAssertEqual(holidayMaps, [
            [2023: [.init(dateString: "2023", localName: "KR", name: "dummy")]],
            [:],
            [2023: [.init(dateString: "2023", localName: "US", name: "dummy")]],
            [2023: [.init(dateString: "2023", localName: "KR", name: "dummy")]],
        ])
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
    }
}
