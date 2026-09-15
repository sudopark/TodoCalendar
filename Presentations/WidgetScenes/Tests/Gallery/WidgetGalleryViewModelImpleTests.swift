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
        setting: WidgetAppearanceSettings = .init(),
        shouldFailChangeSetting: Bool = false,
        styleUsecase: StubWidgetStyleUsecase = .init()
    ) -> WidgetGalleryViewModelImple {
        let usecase = shouldFailChangeSetting
            ? FailingUISettingUsecase() : StubUISettingUsecase()
        let viewModel = WidgetGalleryViewModelImple(
            setting: setting,
            uiSettingUsecase: usecase,
            widgetStyleUsecase: styleUsecase
        )
        viewModel.router = router
        return viewModel
    }

    private func todayStyle(
        _ style: WidgetStyleId.Style,
        variant: WidgetVariant = .todaySummarySmall,
        showHolidayName: Bool
    ) -> WidgetStyle<TodayStyleSetting> {
        return .init(
            id: .init(variant: variant, style: style),
            name: nil,
            setting: TodayStyleSetting.initial |> \.showHolidayName .~ showHolidayName
        )
    }

    private func makeStyleUsecase(
        savedStyles: [WidgetStyle<TodayStyleSetting>]
    ) -> StubWidgetStyleUsecase {
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = savedStyles
        return usecase
    }
}


// MARK: - 기본 스타일

extension WidgetGalleryViewModelImpleTests {

    @Test("꾸미기 가능한 변형의 저장된 기본 스타일을 그 변형 키로 낸다")
    func viewModel_emitsDefaultStyleOfCustomizableVariant() async throws {
        // given
        let expect = expectConfirm("저장된 기본 스타일이 나온다")
        let styleUsecase = self.makeStyleUsecase(
            savedStyles: [self.todayStyle(.default, showHolidayName: false)]
        )
        let viewModel = self.makeViewModel(styleUsecase: styleUsecase)

        // when
        let styles = try await self.firstOutput(expect, for: viewModel.defaultStyles) {
            viewModel.refresh()
        }

        // then
        let todaySetting = styles?[WidgetVariant.todaySummarySmall.id] as? TodayStyleSetting
        #expect(todaySetting?.showHolidayName == false)
    }

    @Test("스타일이 저장되면 바뀐 기본 스타일을 다시 낸다")
    func viewModel_whenStyleUpdated_emitsChangedDefaultStyle() async throws {
        // given
        let expect = expectConfirm("바뀐 기본 스타일이 다시 나온다")
        expect.count = 2
        let styleUsecase = self.makeStyleUsecase(
            savedStyles: [self.todayStyle(.default, showHolidayName: false)]
        )
        let viewModel = self.makeViewModel(styleUsecase: styleUsecase)

        // when
        let styleMaps = try await self.outputs(expect, for: viewModel.defaultStyles) {
            viewModel.refresh()
            styleUsecase.updateStyle(self.todayStyle(.default, showHolidayName: true))
        }

        // then
        let flags = styleMaps.map {
            ($0[WidgetVariant.todaySummarySmall.id] as? TodayStyleSetting)?.showHolidayName
        }
        #expect(flags == [false, true])
    }

    @Test("꾸미기 대상이 아닌 변형은 스타일 사전에 키가 없다")
    func viewModel_hasNoStyleEntryForNonCustomizableVariant() async throws {
        // given
        let expect = expectConfirm("꾸미기 대상 변형만 키를 갖는다")
        let styleUsecase = self.makeStyleUsecase(
            savedStyles: [
                self.todayStyle(.default, showHolidayName: false),
                self.todayStyle(.default, variant: .monthSmall, showHolidayName: true)
            ]
        )
        let viewModel = self.makeViewModel(styleUsecase: styleUsecase)

        // when
        let styles = try await self.firstOutput(expect, for: viewModel.defaultStyles) {
            viewModel.refresh()
        }

        // then
        #expect(styles?.keys.sorted() == [WidgetVariant.todaySummarySmall.id])
        #expect(styles?[WidgetVariant.monthSmall.id] == nil)
    }
}


// MARK: - 목록 노출

extension WidgetGalleryViewModelImpleTests {

    @Test
    func viewModel_emitsAllItemsIncludingDDay() async throws {
        // given
        let expect = expectConfirm("D-day 를 포함한 전 종류가 나온다")
        let viewModel = self.makeViewModel()

        // when
        let items = try await self.firstOutput(expect, for: viewModel.items)

        // then
        #expect(items?.map { $0.id } == WidgetGalleryItem.allCases.map { $0.id })
        #expect(items?.contains(.dday) == true)
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
    func viewModel_whenSelectUnknownItem_doesNotRoute() {
        // given
        let router = SpyWidgetGalleryRouter()
        let viewModel = self.makeViewModel(router: router)

        // when
        viewModel.selectItem("not_exist_item")

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
