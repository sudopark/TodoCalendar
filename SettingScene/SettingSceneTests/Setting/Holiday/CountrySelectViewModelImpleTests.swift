//
//  CountrySelectViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 12/1/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class CountrySelectViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel() -> CountrySelectViewModelImple {
        
        let usecase = StubHolidayUsecase()
        let viewModel = CountrySelectViewModelImple(holidayUsecase: usecase)
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension CountrySelectViewModelImpleTests {
    
    func testViewModel_provideSelectableCountries() {
        // given
        let expect = expectation(description: "선택가능 국가 목록 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let countries = self.waitFirstOutput(expect, for: viewModel.supportCountries) {
            viewModel.prepare()
        }
        
        // then
        let codes = countries?.map { $0.code }
        XCTAssertEqual(codes, ["KST", "US", "Some"])
    }
    
    func testViewModel_updateSelectedCountryCode() {
        // given
        let expect = expectation(description: "선택한 국가 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let codes = self.waitOutputs(expect, for: viewModel.selectedCountryCode) {
            viewModel.prepare()
            
            viewModel.selectCountry("US")
        }
        
        // then
        XCTAssertEqual(codes, ["KST", "US"])
    }
    
    private func makeViewModelWithLoadCountries() -> CountrySelectViewModelImple {
        let expect = expectation(description: "wait")
        let viewModel = self.makeViewModel()
        
        let _ = self.waitFirstOutput(expect, for: viewModel.supportCountries) {
            viewModel.prepare()
        }
        return viewModel
    }
    
    func testViewModel_whenAfterSelectCountry_showToastAndClose() {
        // given
        let expect = expectation(description: "선택국가 저장하고 토스트 노출하고 close")
        let viewModel = self.makeViewModelWithLoadCountries()
        
        self.spyRouter.didCloseCallback = { expect.fulfill() }
        
        // when
        viewModel.selectCountry("US")
        viewModel.confirm()
        self.wait(for: [expect], timeout: self.timeout)
        
        // then
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage != nil, true)
    }
}

private class SpyRouter: BaseSpyRouter, CountrySelectRouting, @unchecked Sendable { }
