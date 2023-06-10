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
        let store = SharedDataStore()
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
