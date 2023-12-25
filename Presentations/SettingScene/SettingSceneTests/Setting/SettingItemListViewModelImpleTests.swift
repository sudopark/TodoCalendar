//
//  SettingItemListViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 11/22/23.
//

import XCTest
import Combine
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class SettingItemListViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
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
    
    private func makeViewModel() -> SettingItemListViewModelImple {
        let viewModel = SettingItemListViewModelImple(
            uiSettingUsecase: StubUISettingUsecase()
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}


extension SettingItemListViewModelImpleTests {
    
    func testViewModel_provideSettingItemSections() {
        // given
        let expect = expectation(description: "세팅 항목 section 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let sections = self.waitFirstOutput(expect, for: viewModel.sectionModels) {
            viewModel.prepare()
        }
        
        // then
        let sectionTitles = sections?.map { $0.headerText }
        XCTAssertEqual(sectionTitles, [
            nil, "Support".localized(), "App".localized(), "Suggest".localized()
        ])
        
        let baseSection = sections?[safe: 0]
        let baseItemIds = baseSection?.items.compactMap { $0 as? SettingItemModel }.map { $0.itemId }
        XCTAssertEqual(baseItemIds, [
            .appearance, .editEvent, .holidaySetting
        ])
        
        let supportSection = sections?[safe: 1]
        let supportItemIds = supportSection?.items.compactMap { $0 as? SettingItemModel }.map { $0.itemId }
        XCTAssertEqual(supportItemIds, [
            .feedback, .faq
        ])
        
        let appInfoSection = sections?[safe: 2]
        let infoItemIds = appInfoSection?.items.compactMap { $0 as? SettingItemModel }.map { $0.itemId }
        XCTAssertEqual(infoItemIds, [
            .shareApp, .addReview, .sourceCode
        ])
        
        let suggestSection = sections?[safe: 3]
        let isSuggestItems = suggestSection?.items.map { $0 as? SuggestAppItemModel }.map { $0 != nil }
        XCTAssertEqual(isSuggestItems, [true])
    }
}


// MARK: - handle routing

extension SettingItemListViewModelImpleTests {
    
    private func WaitItemLoaded(_ viewModel: SettingItemListViewModelImple) -> [any SettingItemModelType] {
        // given
        let expect = expectation(description: "wait items")
        
        // when
        let source = viewModel.sectionModels.map { $0.flatMap { $0.items } }
        let items = self.waitFirstOutput(expect, for: source) {
            viewModel.prepare()
        }
        
        // then
        return items ?? []
    }
    
    func testViewModel_whenSelectSuggestApp_openSafari() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let suggestItem = items.compactMap ({ $0 as? SuggestAppItemModel }).first
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(suggestItem)
        
        // then
        XCTAssertEqual(self.spyRouter.didOpenSafariPath, suggestItem.sourcePath)
    }
    
    func testViewModel_routeToAppearanceSetting() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let appear = items.compactMap ({ $0 as? SettingItemModel }).first(where: { $0.itemId == .appearance })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(appear)
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToAppearanceSetting, true)
    }
    
    func testViewModel_routeToHolidaySetting() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let holiday = items.compactMap({ $0 as? SettingItemModel }).first(where: { $0.itemId == .holidaySetting })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(holiday)
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToHoliday, true)
    }
}

private class SpyRouter: BaseSpyRouter, SettingItemListRouting, @unchecked Sendable {
    
    var didRouteToHoliday: Bool?
    func routeToHolidaySetting() {
        self.didRouteToHoliday = true
    }
    
    var didRouteToAppearanceSetting: Bool?
    func routeToAppearanceSetting(
        inital setting: AppearanceSettings
    ) {
        self.didRouteToAppearanceSetting = true
    }
}
