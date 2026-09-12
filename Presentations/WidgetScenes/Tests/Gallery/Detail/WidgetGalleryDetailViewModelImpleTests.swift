//
//  WidgetGalleryDetailViewModelImpleTests.swift
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
import TestDoubles

@testable import WidgetScenes


final class SpyWidgetGalleryDetailRouter: BaseSpyRouter, WidgetGalleryDetailRouting, @unchecked Sendable {

    private(set) var routedStyleEditVariant: WidgetVariant?

    func routeToStyleEdit(_ variant: WidgetVariant, setting: WidgetAppearanceSettings) {
        self.routedStyleEditVariant = variant
    }
}


struct WidgetGalleryDetailViewModelImpleTests {

    private let cancellables = CancelBag()

    private func makeViewModel(
        _ item: WidgetGalleryItem,
        router: SpyWidgetGalleryDetailRouter,
        setting: WidgetAppearanceSettings = .init(),
        styleUsecase: StubWidgetStyleUsecase = .init()
    ) -> WidgetGalleryDetailViewModelImple {
        let viewModel = WidgetGalleryDetailViewModelImple(
            item: item, setting: setting, widgetStyleUsecase: styleUsecase
        )
        viewModel.router = router
        return viewModel
    }

    private var ddayItem: WidgetGalleryItem { return .dday }

    @Test
    func viewModel_emitsVariantsOfGivenItem() {
        // given
        let item = self.ddayItem
        let viewModel = self.makeViewModel(item, router: .init())
        var emitted: [WidgetVariant]?

        // when
        viewModel.variants
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // then
        #expect(emitted?.map { $0.id } == item.variants.map { $0.id })
        #expect(emitted?.map { $0.canvas.isLockScreen } == [false, false, true, true, true])
    }

    @Test
    func viewModel_emitsItemName() {
        // given
        let item = self.ddayItem
        let viewModel = self.makeViewModel(item, router: .init())
        var emitted: String?

        // when
        viewModel.itemName
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // then
        #expect(emitted == item.name)
    }

    @Test
    func viewModel_emitsGivenSetting() {
        // given
        let setting = WidgetAppearanceSettings() |> \.background .~ .custom(hex: "#123456")
        let viewModel = self.makeViewModel(self.ddayItem, router: .init(), setting: setting)
        var emitted: WidgetAppearanceSettings?
        
        // when
        viewModel.setting
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)
        
        // then
        #expect(emitted?.background == .custom(hex: "#123456"))
    }
    
    @Test
    func viewModel_whenClose_routesToCloseScene() {
        // given
        let router = SpyWidgetGalleryDetailRouter()
        let viewModel = self.makeViewModel(self.ddayItem, router: router)

        // when
        viewModel.close()

        // then
        #expect(router.didClosed == true)
    }
}


// MARK: - 스타일 편집 진입·미리보기

extension WidgetGalleryDetailViewModelImpleTests {

    private func makeTodayViewModel(
        savedHolidayName: Bool?,
        router: SpyWidgetGalleryDetailRouter = .init()
    ) -> WidgetGalleryDetailViewModelImple {
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [
            WidgetStyle(
                id: .init(variant: .todaySummarySmall, style: .default),
                setting: TodayStyleSetting() |> \.showHolidayName .~ savedHolidayName
            )
        ]
        return self.makeViewModel(.todaySummary, router: router, styleUsecase: usecase)
    }

    @Test("꾸미기 가능한 변형의 저장된 기본 스타일을 미리보기에 준다")
    func refresh_provideDefaultStyleOfCustomizableVariant() {
        // given
        let viewModel = self.makeTodayViewModel(savedHolidayName: false)
        var emitted: [String: any WidgetStyleSetting]?
        viewModel.defaultStyles
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // when
        viewModel.refresh()

        // then
        let todayStyle = emitted?[WidgetVariant.todaySummarySmall.id] as? TodayStyleSetting
        #expect(todayStyle?.showHolidayName == false)
    }

    @Test("꾸미기 대상이 아닌 변형은 미리보기 스타일을 갖지 않는다")
    func refresh_notProvideStyleForNotCustomizableVariant() {
        // given
        let viewModel = self.makeViewModel(self.ddayItem, router: .init())
        var emitted: [String: any WidgetStyleSetting]?
        viewModel.defaultStyles
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // when
        viewModel.refresh()

        // then
        #expect(emitted?.isEmpty == true)
        #expect(self.ddayItem.variants.allSatisfy { $0.isCustomizable == false } == true)
    }

    @Test("편집을 고르면 그 변형의 스타일 편집 화면으로 간다")
    func editStyle_routeToStyleEditOfVariant() {
        // given
        let router = SpyWidgetGalleryDetailRouter()
        let viewModel = self.makeTodayViewModel(savedHolidayName: nil, router: router)

        // when
        viewModel.editStyle(.todaySummarySmall)

        // then
        #expect(router.routedStyleEditVariant == .todaySummarySmall)
    }
}
