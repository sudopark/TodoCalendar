//
//  WidgetGalleryViewModelImpleTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import WidgetScenes


private final class FailingUISettingUsecase: StubUISettingUsecase, @unchecked Sendable {

    override func changeWidgetAppearanceSetting(
        _ params: EditWidgetAppearanceSettingParams
    ) throws -> WidgetAppearanceSettings {
        throw RuntimeError("change failed")
    }
}


final class SpyWidgetGalleryRouter: BaseSpyRouter, WidgetGalleryRouting, @unchecked Sendable {

    var didRouteToDetailItem: WidgetGalleryItem?
    var didRouteToDetailWithSetting: WidgetAppearanceSettings?
    func routeToDetail(_ item: WidgetGalleryItem, setting: WidgetAppearanceSettings) {
        self.didRouteToDetailItem = item
        self.didRouteToDetailWithSetting = setting
    }
}


final class WidgetGalleryViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private func makeViewModel(
        router: SpyWidgetGalleryRouter = .init(),
        isDDayWidgetEnabled: Bool = false,
        setting: WidgetAppearanceSettings = .init(),
        shouldFailChangeSetting: Bool = false
    ) -> WidgetGalleryViewModelImple {
        let usecase = shouldFailChangeSetting
            ? FailingUISettingUsecase() : StubUISettingUsecase()
        let viewModel = WidgetGalleryViewModelImple(
            setting: setting,
            uiSettingUsecase: usecase,
            isDDayWidgetEnabled: isDDayWidgetEnabled
        )
        viewModel.router = router
        return viewModel
    }
}


// MARK: - 목록 노출

extension WidgetGalleryViewModelImpleTests {

    @Test
    func viewModel_emitsAllItems() async throws {
        // given
        let expect = expectConfirm("D-day 를 켜면 전 종류가 나온다")
        let viewModel = self.makeViewModel(isDDayWidgetEnabled: true)

        // when
        let items = try await self.firstOutput(expect, for: viewModel.items)

        // then
        #expect(items?.map { $0.id } == WidgetGalleryItem.allCases.map { $0.id })
    }

    @Test
    func viewModel_whenDDayDisabled_emitsItemsWithoutDDay() async throws {
        // given
        let expect = expectConfirm("D-day 를 끄면 그 종류만 빠진다")
        let viewModel = self.makeViewModel(isDDayWidgetEnabled: false)

        // when
        let items = try await self.firstOutput(expect, for: viewModel.items)

        // then
        #expect(items?.contains(.dday) == false)
        #expect(items?.count == WidgetGalleryItem.allCases.count - 1)
    }
}


// MARK: - 상세 진입

extension WidgetGalleryViewModelImpleTests {

    @Test
    func viewModel_whenSelectItem_routesToDetailWithCurrentSetting() {
        // given
        let router = SpyWidgetGalleryRouter()
        let setting = WidgetAppearanceSettings() |> \.background .~ .custom(hex: "#123456")
        let viewModel = self.makeViewModel(router: router, setting: setting)

        // when
        viewModel.selectItem(WidgetGalleryItem.eventList.id)

        // then
        #expect(router.didRouteToDetailItem == .eventList)
        #expect(router.didRouteToDetailWithSetting?.background == .custom(hex: "#123456"))
    }

    @Test
    func viewModel_whenSelectHiddenItem_doesNotRoute() {
        // given
        let router = SpyWidgetGalleryRouter()
        let viewModel = self.makeViewModel(router: router, isDDayWidgetEnabled: false)

        // when
        viewModel.selectItem(WidgetGalleryItem.dday.id)

        // then
        #expect(router.didRouteToDetailItem == nil)
    }

    @Test
    func viewModel_whenSelectItemAfterThemeChanged_routesWithChangedSetting() {
        // given
        let router = SpyWidgetGalleryRouter()
        let viewModel = self.makeViewModel(router: router)

        // when
        viewModel.selectCustomBackground(hex: "#ABCDEF")
        viewModel.selectItem(WidgetGalleryItem.month.id)

        // then
        #expect(router.didRouteToDetailWithSetting?.background == .custom(hex: "#ABCDEF"))
    }

    @Test
    func viewModel_whenClose_routesToCloseScene() {
        // given
        let router = SpyWidgetGalleryRouter()
        let viewModel = self.makeViewModel(router: router)

        // when
        viewModel.close()

        // then
        #expect(router.didClosed == true)
    }
}


// MARK: - 기본 테마 변경

extension WidgetGalleryViewModelImpleTests {

    @Test
    func viewModel_whenSelectCustomBackground_emitsChangedSetting() async throws {
        // given
        let expect = expectConfirm("커스텀 색을 고르면 설정이 다시 방출된다")
        expect.count = 2
        let viewModel = self.makeViewModel()

        // when
        let settings = try await self.outputs(expect, for: viewModel.setting) {
            viewModel.selectCustomBackground(hex: "#FF0000")
        }

        // then
        #expect(settings.map { $0.background } == [.system, .custom(hex: "#FF0000")])
    }

    @Test
    func viewModel_whenSelectSystemTheme_emitsChangedSetting() async throws {
        // given
        let expect = expectConfirm("시스템 테마로 되돌리면 설정이 다시 방출된다")
        expect.count = 2
        let setting = WidgetAppearanceSettings() |> \.background .~ .custom(hex: "#FF0000")
        let viewModel = self.makeViewModel(setting: setting)

        // when
        let settings = try await self.outputs(expect, for: viewModel.setting) {
            viewModel.selectSystemTheme()
        }

        // then
        #expect(settings.map { $0.background } == [.custom(hex: "#FF0000"), .system])
    }

    @Test
    func viewModel_whenChangeSettingFails_showsError() {
        // given
        let router = SpyWidgetGalleryRouter()
        let viewModel = self.makeViewModel(router: router, shouldFailChangeSetting: true)

        // when
        viewModel.selectCustomBackground(hex: "#FF0000")

        // then
        #expect(router.didShowError != nil)
    }
}
