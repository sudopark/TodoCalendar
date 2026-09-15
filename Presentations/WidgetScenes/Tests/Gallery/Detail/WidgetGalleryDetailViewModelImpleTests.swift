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

    private func todayStyle(
        _ style: WidgetStyleId.Style,
        holiday: Bool = true,
        timeZone: Bool = true,
        monthYear: Bool = true
    ) -> WidgetStyle<TodayStyleSetting> {
        let setting = TodayStyleSetting.initial
            |> \.showHolidayName .~ holiday
            |> \.showTimeZone .~ timeZone
            |> \.showMonthYear .~ monthYear
        return .init(
            id: .init(variant: .todaySummarySmall, style: style), name: nil, setting: setting
        )
    }

    private func makeTodayViewModel(
        savedStyles: [WidgetStyle<TodayStyleSetting>] = [],
        router: SpyWidgetGalleryDetailRouter = .init()
    ) -> (WidgetGalleryDetailViewModelImple, StubWidgetStyleUsecase) {
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = savedStyles
        let viewModel = self.makeViewModel(
            .todaySummary, router: router, styleUsecase: usecase
        )
        return (viewModel, usecase)
    }

    private func todaySettings(
        _ stack: WidgetPreviewStyleStack?
    ) -> (base: TodayStyleSetting?, overlays: [TodayStyleSetting]) {
        return (
            stack?.base as? TodayStyleSetting,
            stack?.overlays.compactMap { $0 as? TodayStyleSetting } ?? []
        )
    }

    @Test("저장된 기본 스타일이 프리뷰 스택의 맨 앞 장이 된다")
    func previewStyles_emitsDefaultStyleAsBase() async throws {
        // given
        let defaultStyle = self.todayStyle(.default, holiday: false)
        let (viewModel, _) = self.makeTodayViewModel(savedStyles: [defaultStyle])

        // when
        let emitted = try await self.currentAfterRefresh("프리뷰 스택", of: viewModel)

        // then
        let stack = self.todaySettings(emitted?[WidgetVariant.todaySummarySmall.id])
        #expect(stack.base == defaultStyle.setting)
    }

    @Test("커스텀 스타일이 없으면 겹쳐 깔 장이 없다")
    func previewStyles_whenNoCustomStyle_hasNoOverlay() async throws {
        // given
        let (viewModel, _) = self.makeTodayViewModel(
            savedStyles: [self.todayStyle(.default, holiday: false)]
        )

        // when
        let emitted = try await self.currentAfterRefresh("프리뷰 스택", of: viewModel)

        // then
        let stack = emitted?[WidgetVariant.todaySummarySmall.id]
        #expect(stack?.overlays.isEmpty == true)
    }

    @Test("커스텀 스타일이 두 장이면 목록 순서 그대로 둘 다 겹쳐 깐다")
    func previewStyles_whenTwoCustomStyles_stacksBothInListOrder() async throws {
        // given
        let customs = [
            self.todayStyle(.custom(id: "c1"), timeZone: true),
            self.todayStyle(.custom(id: "c2"), monthYear: true)
        ]
        let (viewModel, _) = self.makeTodayViewModel(
            savedStyles: [self.todayStyle(.default, holiday: false)] + customs
        )

        // when
        let emitted = try await self.currentAfterRefresh("프리뷰 스택", of: viewModel)

        // then
        let stack = emitted?[WidgetVariant.todaySummarySmall.id]
        #expect(self.todaySettings(stack).overlays == customs.map { $0.setting })
    }

    @Test("커스텀 스타일이 두 장을 넘어도 앞 두 장까지만 깐다")
    func previewStyles_whenMoreThanTwoCustomStyles_stacksFirstTwoOnly() async throws {
        // given
        let customs = [
            self.todayStyle(.custom(id: "c1"), timeZone: true),
            self.todayStyle(.custom(id: "c2"), monthYear: true),
            self.todayStyle(.custom(id: "c3"), holiday: true)
        ]
        let (viewModel, _) = self.makeTodayViewModel(
            savedStyles: [self.todayStyle(.default, holiday: false)] + customs
        )

        // when
        let emitted = try await self.currentAfterRefresh("프리뷰 스택", of: viewModel)

        // then
        let stack = emitted?[WidgetVariant.todaySummarySmall.id]
        #expect(self.todaySettings(stack).overlays == customs.prefix(2).map { $0.setting })
    }

    @Test("커스텀 스타일을 지우면 그만큼 줄어든 스택을 다시 낸다")
    func previewStyles_whenCustomStyleRemoved_emitsShrunkStack() async throws {
        // given
        let expect = expectConfirm("줄어든 스택이 다시 나온다")
        expect.count = 2
        let removing = self.todayStyle(.custom(id: "c1"), timeZone: true)
        let remaining = self.todayStyle(.custom(id: "c2"), monthYear: true)
        let (viewModel, usecase) = self.makeTodayViewModel(
            savedStyles: [self.todayStyle(.default, holiday: false), removing, remaining]
        )

        // when
        let emitted = try await self.outputs(expect, for: viewModel.previewStyles) {
            viewModel.refresh()
            usecase.removeStyle(TodayStyleSetting.self, removing.id)
        }

        // then
        let overlayLists = emitted.map {
            self.todaySettings($0[WidgetVariant.todaySummarySmall.id]).overlays
        }
        #expect(overlayLists == [
            [removing.setting, remaining.setting], [remaining.setting]
        ])
    }

    @Test("꾸미기 대상이 아닌 항목은 프리뷰 스택을 갖지 않는다")
    func previewStyles_hasNoEntryForNonCustomizableVariant() async throws {
        // given
        let viewModel = self.makeViewModel(self.ddayItem, router: .init())

        // when
        let emitted = try await self.currentAfterRefresh("프리뷰 스택", of: viewModel)

        // then
        #expect(emitted?.isEmpty == true)
        #expect(self.ddayItem.variants.allSatisfy { $0.isCustomizable == false } == true)
    }

    @Test("편집을 고르면 그 변형의 스타일 편집 화면으로 간다")
    func editStyle_routeToStyleEditOfVariant() {
        // given
        let router = SpyWidgetGalleryDetailRouter()
        let (viewModel, _) = self.makeTodayViewModel(router: router)

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

    private func currentAfterRefresh(
        _ description: String, of viewModel: WidgetGalleryDetailViewModelImple
    ) async throws -> [String: WidgetPreviewStyleStack]? {
        return try await self.firstOutput(
            self.expectConfirm(description), for: viewModel.previewStyles
        ) {
            viewModel.refresh()
        }
    }
}
