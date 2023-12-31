//
//  EventSettingViewModelImpleTests.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene

class EventSettingViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var stubSettingUsecase: StubEventSettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.stubSettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.stubSettingUsecase = nil
    }
    
    private func makeViewModel() -> EventSettingViewModelImple {
        let tagUsecase = StubEventTagUsecase()
        let viewModel = EventSettingViewModelImple(
            eventSettingUsecase: self.stubSettingUsecase,
            eventTagUsecase: tagUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension EventSettingViewModelImpleTests {
    
    // 선택된 태그 정보 반환
    func testViewModel_provideCurrentNewDefaultTag() {
        // given
        let expect = expectation(description: "선택된 태그 정보 반환")
        let viewModel = self.makeViewModel()
        
        // when
        let model = self.waitFirstOutput(expect, for: viewModel.selectedTagModel) { 
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(model?.id, .default)
        XCTAssertEqual(model?.name, "default".localized())
    }
    
    // 태그 선택화면으로 이동 및 업데이트
    func testViewModel_changeNewDefaultTagSetting() {
        // given
        let expect = expectation(description: "태그 선택화면으로 이동 및 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.selectedTagModel) {
            viewModel.prepare()
            
            viewModel.selectTag()
            
            let params = EditEventSettingsParams() |> \.defaultNewEventTagId .~ .custom("some")
            _ = try! self.stubSettingUsecase.changeEventSetting(params)
        }
        
        // then
        let ids = models.map { $0.id }
        XCTAssertEqual(ids, [.default, .custom("some")])
        XCTAssertEqual(self.spyRouter.didRouteToSelectTag, true)
    }
    
    // 선택된 기간정보 반환
    func testViewModel_provideSelectedNewEventDefaultPeriod() {
        // given
        let expect = expectation(description: "선택된 기간정보 반환")
        let viewModel = self.makeViewModel()
        
        // when
        let period = self.waitFirstOutput(expect, for: viewModel.selectedPeriod) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(period?.period, .hour1)
    }
    
    // 기간 업데이트
    func testViewModel_updateSelectedNewEventDefaultPeriod() {
        // given
        let expect = expectation(description: "기간 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let periods = self.waitOutputs(expect, for: viewModel.selectedPeriod) {
            viewModel.prepare()
            
            viewModel.selectPeriod(.minute10)
        }
        
        // then
        XCTAssertEqual(periods.map { $0.period }, [.hour1, .minute10])
    }
}

private class SpyRouter: BaseSpyRouter, EventSettingRouting, @unchecked Sendable {
    
    var didRouteToSelectTag: Bool?
    func routeToSelectTag() {
        self.didRouteToSelectTag = true
    }
}
