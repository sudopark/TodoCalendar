//
//  WidgetStyleEditViewModelImpleTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/12/26.
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


final class SpyWidgetStyleEditRouter: BaseSpyRouter, WidgetStyleEditRouting, @unchecked Sendable { }


struct WidgetStyleEditViewModelImpleTests {

    private let cancellables = CancelBag()

    private func todayStyle(
        _ style: WidgetStyleId.Style, showHolidayName: Bool? = nil
    ) -> WidgetStyle<TodayStyleSetting> {
        return .init(
            id: .init(variant: .todaySummarySmall, style: style),
            setting: TodayStyleSetting() |> \.showHolidayName .~ showHolidayName
        )
    }

    private func makeViewModel(
        _ usecase: StubWidgetStyleUsecase,
        router: SpyWidgetStyleEditRouter = .init()
    ) -> WidgetStyleEditViewModelImple {
        let viewModel = WidgetStyleEditViewModelImple(
            variant: .todaySummarySmall, widgetStyleUsecase: usecase
        )
        viewModel.router = router
        return viewModel
    }
}


// MARK: - 스타일 목록·선택

extension WidgetStyleEditViewModelImpleTests {

    @Test("진입하면 조회한 변형의 스타일 목록을 낸다")
    func refresh_provideStyleListOfVariant() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [
            self.todayStyle(.default, showHolidayName: false),
            self.todayStyle(.custom(id: "여름"))
        ]
        let viewModel = self.makeViewModel(usecase)
        var emitted: [WidgetStyleCellViewModel]?
        viewModel.styles
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // when
        viewModel.refresh()

        // then
        #expect(usecase.requestedVariant == .todaySummarySmall)
        #expect(emitted?.map { $0.styleId.style } == [.default, .custom(id: "여름")])
        #expect(emitted?.map { $0.name } == ["widget.style::default".localized(), "여름"])
        #expect(emitted?.first?.setting.showHolidayName == false)
    }

    @Test("다른 스타일을 고르면 항목 값이 그 스타일 내용으로 바뀐다")
    func selectStyle_updateItemValues() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [
            self.todayStyle(.default, showHolidayName: false),
            self.todayStyle(.custom(id: "c1"), showHolidayName: true)
        ]
        let viewModel = self.makeViewModel(usecase)
        var emitted: [WidgetStyleItemCellViewModel]?
        viewModel.items
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)
        viewModel.refresh()

        // when
        viewModel.selectStyle(.init(variant: .todaySummarySmall, style: .custom(id: "c1")))

        // then
        #expect(emitted?.first(where: { $0.item == .showHolidayName })?.isOn == true)
    }

    @Test("값이 상황을 타는 항목에만 부연 설명이 붙는다")
    func items_onlyConditionalOnesHaveNote() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [self.todayStyle(.default)]
        let viewModel = self.makeViewModel(usecase)
        var emitted: [WidgetStyleItemCellViewModel]?
        viewModel.items
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // when
        viewModel.refresh()

        // then
        let withNote = emitted?.filter { $0.note != nil }.map { $0.item }
        #expect(withNote == [.showHolidayName, .showTimeZone])
    }

    @Test("스타일 항목은 미설정이면 켜진 것으로 보인다")
    func items_whenNotSpecified_areOn() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [self.todayStyle(.default)]
        let viewModel = self.makeViewModel(usecase)
        var emitted: [WidgetStyleItemCellViewModel]?
        viewModel.items
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // when
        viewModel.refresh()

        // then
        #expect(emitted?.map { $0.item } == TodayStyleItem.allCases)
        #expect(emitted?.allSatisfy { $0.isOn } == true)
    }
}


// MARK: - 편집·저장

extension WidgetStyleEditViewModelImpleTests {

    @Test("항목을 꺼도 확인 전에는 저장하지 않는다")
    func toggleItem_notSaveUntilConfirm() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [self.todayStyle(.default)]
        let viewModel = self.makeViewModel(usecase)
        var emitted: [WidgetStyleItemCellViewModel]?
        viewModel.items
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)
        viewModel.refresh()

        // when
        viewModel.toggleItem(.showTimeZone)

        // then
        #expect(emitted?.first(where: { $0.item == .showTimeZone })?.isOn == false)
        #expect(usecase.updatedSetting == nil)
    }

    @Test("확인하면 조작한 설정을 고른 스타일 좌표에 저장하고 화면을 닫는다")
    func confirm_saveToggledSettingToSelectedStyle() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [
            self.todayStyle(.default),
            self.todayStyle(.custom(id: "c1"))
        ]
        let router = SpyWidgetStyleEditRouter()
        let viewModel = self.makeViewModel(usecase, router: router)
        viewModel.refresh()
        viewModel.selectStyle(.init(variant: .todaySummarySmall, style: .custom(id: "c1")))

        // when
        viewModel.toggleItem(.showScheduleCount)
        viewModel.confirm()

        // then
        let saved = usecase.updatedSetting as? TodayStyleSetting
        #expect(saved?.showScheduleCount == false)
        #expect(saved?.showHolidayName == nil)
        #expect(usecase.updatedStyleId == .init(variant: .todaySummarySmall, style: .custom(id: "c1")))
        #expect(router.didClosed == true)
    }

    @Test("확인 없이 닫으면 저장하지 않는다")
    func close_withoutConfirm_notSave() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [self.todayStyle(.default)]
        let router = SpyWidgetStyleEditRouter()
        let viewModel = self.makeViewModel(usecase, router: router)
        viewModel.refresh()
        viewModel.toggleItem(.showTodoCount)

        // when
        viewModel.close()

        // then
        #expect(usecase.updatedSetting == nil)
        #expect(usecase.updatedStyleId == nil)
        #expect(router.didClosed == true)
    }

    @Test("고른 카드는 편집 중인 설정을 그린다")
    func styles_selectedCardShowsEditingSetting() {
        // given
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = [self.todayStyle(.default)]
        let viewModel = self.makeViewModel(usecase)
        var emitted: [WidgetStyleCellViewModel]?
        viewModel.styles
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)
        viewModel.refresh()

        // when
        viewModel.toggleItem(.showTotalCount)

        // then
        #expect(emitted?.first?.setting.showTotalCount == false)
    }
}
