//
//  SettingItemListViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 11/22/23.
//

import XCTest
import Combine
import Prelude
import Optics
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
    
    private func makeViewModel(_ account: AccountInfo? = nil) -> SettingItemListViewModelImple {
        let accountUsecase = StubAccountUsecase(account)
        let viewModel = SettingItemListViewModelImple(
            appstoreLinkPath: "some",
            accountUsecase: accountUsecase,
            uiSettingUsecase: StubUISettingUsecase(),
            deviceInfoFetchService: StubDeviceInfoFetchService()
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
        let sections = self.waitFirstOutput(expect, for: viewModel.sectionModels)
        
        // then
        let sectionTitles = sections?.map { $0.headerText }
        XCTAssertEqual(sectionTitles, [
            nil,
            "setting.section.support::name".localized(),
            "setting.section.app::name".localized(),
            "setting.section.suggest::name".localized()
        ])
        
        let baseSection = sections?[safe: 0]
        let baseItemIds = baseSection?.items.compactMap { $0 as? SettingItemModel }.map { $0.itemId }
        XCTAssertEqual(baseItemIds, [
            .appearance, .editEvent, .holidaySetting
        ])
        let accountItem = baseSection?.items.last as? AccountSettingItemModel
        XCTAssertEqual(accountItem?.isSignIn, false)
        
        let supportSection = sections?[safe: 1]
        let supportItemIds = supportSection?.items.compactMap { $0 as? SettingItemModel }.map { $0.itemId }
        XCTAssertEqual(supportItemIds, [
            .feedback, .help
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
    
    func testViewModel_whenSignIn_provideItemSections() {
        // given
        let expect = expectation(description: "세팅 항목 section 제공")
        let viewModel = self.makeViewModel(AccountInfo("some"))
        
        // when
        let sections = self.waitFirstOutput(expect, for: viewModel.sectionModels)
        
        // then
        let sectionTitles = sections?.map { $0.headerText }
        XCTAssertEqual(sectionTitles, [
            nil,
            "setting.section.support::name".localized(),
            "setting.section.app::name".localized(),
            "setting.section.suggest::name".localized()
        ])
        
        let baseSection = sections?[safe: 0]
        let baseItemIds = baseSection?.items.compactMap { $0 as? SettingItemModel }.map { $0.itemId }
        XCTAssertEqual(baseItemIds, [
            .appearance, .editEvent, .holidaySetting
        ])
        let accountItem = baseSection?.items.last as? AccountSettingItemModel
        XCTAssertEqual(accountItem?.isSignIn, true)
        
        let supportSection = sections?[safe: 1]
        let supportItemIds = supportSection?.items.compactMap { $0 as? SettingItemModel }.map { $0.itemId }
        XCTAssertEqual(supportItemIds, [
            .feedback, .help
        ])
        
        let appInfoSection = sections?[safe: 2]
        XCTAssertEqual(appInfoSection is AppInfoSectionModel, true)
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
        let items = self.waitFirstOutput(expect, for: source)
        
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
    
    func testViewModel_routeToEventSetting() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let event = items.compactMap ({ $0 as? SettingItemModel }).first(where: { $0.itemId == .editEvent })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(event)
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToEventSetting, true)
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
    
    func testViewModel_routeToFeedbackPost() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let feedback = items.compactMap({ $0 as? SettingItemModel }).first(where: { $0.itemId == .feedback })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(feedback)
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToFeedback, true)
    }
    
    func testViewModel_routeShareApp() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let share = items.compactMap({ $0 as? SettingItemModel }).first(where: { $0.itemId == .shareApp })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(share)
        
        // then
        XCTAssertEqual(self.spyRouter.didOpenShareLink, true)
    }
    
    func testViewModel_routeToAppReview() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let review = items.compactMap({ $0 as? SettingItemModel }).first(where: { $0.itemId == .addReview })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(review)
        
        // then
        XCTAssertEqual(self.spyRouter.didOpenSafariPath, "some")
    }
    
    func testViewModel_showHelpPage() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let help = items.compactMap ({ $0 as? SettingItemModel }).first(where: { $0.itemId == .help })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(help)
        
        // then
        let expectPath = Locale.current.language.languageCode == .korean
        ? "https://readmind.notion.site/To-do-Calendar-36cba0bdc84b44de9abdfd7d8721cd91"
        : "https://readmind.notion.site/To-do-Calendar-Help-a2183ee1a41946faa8e0658640fb4c6a?pvs=4"
        XCTAssertEqual(self.spyRouter.didOpenSafariPath, expectPath)
    }
    
    func testViewModel_routeToSourceCode() {
        // given
        let viewModel = self.makeViewModel()
        let items = self.WaitItemLoaded(viewModel)
        
        // when
        guard let source = items.compactMap({ $0 as? SettingItemModel }).first(where: { $0.itemId == .sourceCode })
        else {
            XCTAssert(false)
            return
        }
        viewModel.selectItem(source)
        
        // then
        XCTAssertEqual(self.spyRouter.didOpenSafariPath, "https://github.com/sudopark/TodoCalendar")
    }
}

private class SpyRouter: BaseSpyRouter, SettingItemListRouting, @unchecked Sendable {
    
    var didRouteToHoliday: Bool?
    func routeToHolidaySetting() {
        self.didRouteToHoliday = true
    }
    
    var didRouteToAppearanceSetting: Bool?
    func routeToAppearanceSetting(
        inital setting: CalendarAppearanceSettings
    ) {
        self.didRouteToAppearanceSetting = true
    }
    
    var didRouteToEventSetting: Bool?
    func routeToEventSetting() {
        self.didRouteToEventSetting = true
    }
    
    var didRouteToSignIn: Bool?
    func routeToSignIn() {
        self.didRouteToSignIn = true
    }
    
    var didRouteToAccountManage: Bool?
    func routeToAccountManage() {
        self.didRouteToAccountManage = true
    }
    
    var didRouteToFeedback: Bool?
    func routeToFeedbackPost() {
        self.didRouteToFeedback = true
    }
    
    var didOpenShareLink: Bool?
    func openShare(link path: String) {
        self.didOpenShareLink = true
    }
}


private struct StubDeviceInfoFetchService: DeviceInfoFetchService {
    
    @MainActor
    func fetchDeviceInfo() async -> DeviceInfo {
        return DeviceInfo()
            |> \.appVersion .~ "app"
            |> \.osVersion .~ "os"
            |> \.deviceModel .~ "model"
    }
}
