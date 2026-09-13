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
import UnitTestHelpKit
import TestDoubles

@testable import WidgetScenes


final class SpyWidgetGalleryDetailRouter: BaseSpyRouter, WidgetGalleryDetailRouting, @unchecked Sendable {

    private(set) var routedStyleEditVariant: WidgetVariant?

    func routeToStyleEdit(_ variant: WidgetVariant, setting: WidgetAppearanceSettings) {
        self.routedStyleEditVariant = variant
    }
}


final class WidgetGalleryDetailViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

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
    func viewModel_emitsVariantsOfGivenItem() async throws {
        // given
        let item = self.ddayItem
        let viewModel = self.makeViewModel(item, router: .init())

        // when
        let emitted = try await self.current("변형 목록", of: viewModel.variants)

        // then
        #expect(emitted?.map { $0.id } == item.variants.map { $0.id })
        #expect(emitted?.map { $0.canvas.isLockScreen } == [false, false, true, true, true])
    }

    @Test
    func viewModel_emitsItemName() async throws {
        // given
        let item = self.ddayItem
        let viewModel = self.makeViewModel(item, router: .init())

        // when
        let emitted = try await self.current("항목 이름", of: viewModel.itemName)

        // then
        #expect(emitted == item.name)
    }

    @Test
    func viewModel_emitsGivenSetting() async throws {
        // given
        let setting = WidgetAppearanceSettings() |> \.background .~ .custom(hex: "#123456")
        let viewModel = self.makeViewModel(self.ddayItem, router: .init(), setting: setting)

        // when
        let emitted = try await self.current("위젯 전체 설정", of: viewModel.setting)

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
                name: nil,
                setting: TodayStyleSetting() |> \.showHolidayName .~ savedHolidayName
            )
        ]
        return self.makeViewModel(.todaySummary, router: router, styleUsecase: usecase)
    }

    @Test("꾸미기 가능한 변형의 저장된 기본 스타일을 미리보기에 준다")
    func refresh_provideDefaultStyleOfCustomizableVariant() async throws {
        // given
        let viewModel = self.makeTodayViewModel(savedHolidayName: false)

        // when
        viewModel.refresh()

        // then
        let emitted = try await self.current("미리보기 기본 스타일", of: viewModel.defaultStyles)
        let todayStyle = emitted?[WidgetVariant.todaySummarySmall.id] as? TodayStyleSetting
        #expect(todayStyle?.showHolidayName == false)
    }

    @Test("꾸미기 대상이 아닌 변형은 미리보기 스타일을 갖지 않는다")
    func refresh_notProvideStyleForNotCustomizableVariant() async throws {
        // given
        let viewModel = self.makeViewModel(self.ddayItem, router: .init())

        // when
        viewModel.refresh()

        // then
        let emitted = try await self.current("미리보기 기본 스타일", of: viewModel.defaultStyles)
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


// MARK: - 출력 읽기

extension WidgetGalleryDetailViewModelImpleTests {

    private func current<P: Publisher>(
        _ description: String, of source: P
    ) async throws -> P.Output? where P.Output: Sendable {
        return try await self.firstOutput(self.expectConfirm(description), for: source)
    }
}
