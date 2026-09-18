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
import UnitTestHelpKit
import TestDoubles

@testable import WidgetScenes


final class SpyWidgetStyleEditRouter: BaseSpyRouter, WidgetStyleEditRouting, @unchecked Sendable { }


private struct OtherWidgetStyleSetting: WidgetStyleSetting {

    var isOn: Bool

    static let initial = OtherWidgetStyleSetting(isOn: true)
}


final class WidgetStyleEditViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()

    private var defaultId: WidgetStyleId {
        return .init(variant: .todaySummarySmall, style: .default)
    }

    private var customId: WidgetStyleId {
        return .init(variant: .todaySummarySmall, style: .custom(id: "c1"))
    }

    private func todayStyle(
        _ style: WidgetStyleId.Style,
        variant: WidgetVariant = .todaySummarySmall,
        name: String? = nil,
        showHolidayName: Bool = true,
        background: WidgetAppearanceSettings.Background? = nil
    ) -> WidgetStyle {
        return .init(
            id: .init(variant: variant, style: style),
            name: name,
            setting: TodayStyleSetting.initial |> \.showHolidayName .~ showHolidayName,
            background: background
        )
    }

    private func weekEventsStyle(
        _ style: WidgetStyleId.Style,
        variant: WidgetVariant = .oneWeekEvents,
        name: String? = nil,
        showWeekDayHeader: Bool = true
    ) -> WidgetStyle {
        return .init(
            id: .init(variant: variant, style: style),
            name: name,
            setting: WeekEventsStyleSetting.initial |> \.showWeekDayHeader .~ showWeekDayHeader
        )
    }

    /// 편집 뷰모델은 항목이 아니라 설정 전체를 받으므로, 초기값에서 항목을 끈 설정을 만들어 넘긴다.
    private func settingTurningOff(_ items: TodayStyleItem...) -> TodayStyleSetting {
        return items.reduce(TodayStyleSetting.initial) { acc, item in
            acc |> item.settingKeyPath .~ false
        }
    }
}


// MARK: - 화면 만들기

extension WidgetStyleEditViewModelImpleTests {

    private func makeUsecase(
        saved styles: [WidgetStyle]
    ) -> StubWidgetStyleUsecase {
        let usecase = StubWidgetStyleUsecase()
        usecase.stubStyles = styles
        return usecase
    }

    private func makeViewModel(
        _ usecase: StubWidgetStyleUsecase,
        router: SpyWidgetStyleEditRouter = .init()
    ) -> WidgetStyleEditViewModelImple {
        let viewModel = WidgetStyleEditViewModelImple(
            variants: [.todaySummarySmall], widgetStyleUsecase: usecase
        )
        viewModel.router = router
        return viewModel
    }

    /// 저장된 목록으로 화면을 세우고 진입까지 마친다.
    private func makeViewModel(
        saved styles: [WidgetStyle],
        router: SpyWidgetStyleEditRouter = .init()
    ) -> (WidgetStyleEditViewModelImple, StubWidgetStyleUsecase) {
        let usecase = self.makeUsecase(saved: styles)
        let viewModel = self.makeViewModel(usecase, router: router)
        viewModel.refresh()
        return (viewModel, usecase)
    }

    private func makeViewModelWithDefaultOnly(
        name: String? = nil,
        showHolidayName: Bool = true,
        router: SpyWidgetStyleEditRouter = .init()
    ) -> (WidgetStyleEditViewModelImple, StubWidgetStyleUsecase) {
        return self.makeViewModel(
            saved: [self.todayStyle(.default, name: name, showHolidayName: showHolidayName)],
            router: router
        )
    }

    /// 기본 카드와 커스텀 카드 하나가 저장된 화면 — 고른 것은 기본 카드다.
    private func makeViewModelWithCustom(
        name: String? = nil,
        showHolidayName: Bool = true,
        router: SpyWidgetStyleEditRouter = .init()
    ) -> (WidgetStyleEditViewModelImple, StubWidgetStyleUsecase) {
        return self.makeViewModel(
            saved: [
                self.todayStyle(.default),
                self.todayStyle(.custom(id: "c1"), name: name, showHolidayName: showHolidayName)
            ],
            router: router
        )
    }

    private func makeViewModelSelectingCustom(
        name: String? = nil,
        router: SpyWidgetStyleEditRouter = .init()
    ) -> (WidgetStyleEditViewModelImple, StubWidgetStyleUsecase) {
        let made = self.makeViewModelWithCustom(name: name, router: router)
        made.0.selectStyle(self.customId)
        return made
    }

    /// 기본 카드에만 미저장 편집분이 있는 화면 — 고른 것도 기본 카드다.
    private func makeViewModelWithEdit(
        router: SpyWidgetStyleEditRouter = .init()
    ) -> (WidgetStyleEditViewModelImple, StubWidgetStyleUsecase) {
        let made = self.makeViewModelWithCustom(name: "밤 모드", router: router)
        made.0.updateSetting(self.settingTurningOff(.showTodoCount))
        return made
    }

    /// 기본·커스텀 양쪽에 미저장 편집분이 있고 커스텀을 고른 화면.
    private func makeViewModelWithEditOnBothCards(
        router: SpyWidgetStyleEditRouter = .init()
    ) -> (WidgetStyleEditViewModelImple, StubWidgetStyleUsecase) {
        let made = self.makeViewModelWithCustom(router: router)
        made.0.updateSetting(self.settingTurningOff(.showTodoCount))
        made.0.selectStyle(self.customId)
        made.0.updateSetting(self.settingTurningOff(.showScheduleCount))
        return made
    }

    /// 닫기 시트에서 고를 항목을 미리 정해 둔다.
    private func mockSheetSelection(_ router: SpyWidgetStyleEditRouter, key: String) {
        router.actionSheetSelectionMocking = { form in
            form.actions.first(where: { $0.text == key.localized() })
        }
    }
}


// MARK: - 출력 읽기

extension WidgetStyleEditViewModelImpleTests {

    private func current<P: Publisher>(
        _ description: String, of source: P
    ) async throws -> P.Output? where P.Output: Sendable {
        return try await self.firstOutput(self.expectConfirm(description), for: source)
    }

    private func styles(
        of viewModel: WidgetStyleEditViewModelImple
    ) async throws -> [WidgetStyleCellViewModel] {
        return try await self.current("카드 목록", of: viewModel.styles) ?? []
    }

    private func selectedSetting(
        of viewModel: WidgetStyleEditViewModelImple
    ) async throws -> TodayStyleSetting? {
        return try await self.current("고른 설정", of: viewModel.selectedSetting)
            as? TodayStyleSetting
    }

    private func selectedStyleId(
        of viewModel: WidgetStyleEditViewModelImple
    ) async throws -> WidgetStyleId? {
        return try await self.current("고른 카드", of: viewModel.selectedStyleId)
    }

    private func editingName(
        of viewModel: WidgetStyleEditViewModelImple
    ) async throws -> String? {
        return try await self.current("이름 입력 값", of: viewModel.editingName)
    }

    private func hasUnsavedChange(
        of viewModel: WidgetStyleEditViewModelImple
    ) async throws -> Bool? {
        return try await self.current("고른 카드 미저장 여부", of: viewModel.hasUnsavedChange)
    }

    private func hasAnyUnsavedEdit(
        of viewModel: WidgetStyleEditViewModelImple
    ) async throws -> Bool? {
        return try await self.current("목록 전체 미저장 여부", of: viewModel.hasAnyUnsavedEdit)
    }

    /// 바깥은 이중 Optional 이다 — 방출 여부와 "전역 따름(nil)"을 갈라 봐야 한다.
    private func selectedBackground(
        of viewModel: WidgetStyleEditViewModelImple
    ) async throws -> WidgetAppearanceSettings.Background?? {
        return try await self.current("고른 카드 배경색", of: viewModel.selectedBackground)
    }

    /// 이름 입력 값이 되돌아오는 흐름 자체를 봐야 하는 케이스용 — 방출 순서를 모은다.
    private func editingNames(
        of viewModel: WidgetStyleEditViewModelImple,
        count: Int,
        whileDoing action: @escaping () -> Void
    ) async throws -> [String] {
        let expect = self.expectConfirm("이름 입력 값 방출")
        expect.count = count
        return try await self.outputs(expect, for: viewModel.editingName) { action() }
    }
}


// MARK: - 스타일 목록·선택

extension WidgetStyleEditViewModelImpleTests {

    @Test("진입하면 조회한 변형의 스타일 목록을 낸다")
    func refresh_provideStyleListOfVariant() async throws {
        // given
        let usecase = self.makeUsecase(saved: [
            self.todayStyle(.default, showHolidayName: false),
            self.todayStyle(.custom(id: "c1"), name: "여름")
        ])
        let viewModel = self.makeViewModel(usecase)

        // when
        viewModel.refresh()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(usecase.requestedVariant == .todaySummarySmall)
        #expect(emitted.map { $0.styleId.style } == [.default, .custom(id: "c1")])
        #expect(emitted.map { $0.name } == ["widget.style::default".localized(), "여름"])
        #expect((emitted.first?.setting as? TodayStyleSetting)?.showHolidayName == false)
    }

    @Test("고른 카드가 바뀌면 그 카드의 설정이 흘러나온다")
    func selectStyle_emitsSettingOfSelectedCard() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(saved: [
            self.todayStyle(.default, showHolidayName: false),
            self.todayStyle(.custom(id: "c1"), showHolidayName: true)
        ])

        // when
        viewModel.selectStyle(self.customId)

        // then
        let emitted = try await self.selectedSetting(of: viewModel)
        #expect(emitted?.showHolidayName == true)
    }

    @Test("저장된 설정이 없으면 고른 카드의 설정이 초기값 그대로다")
    func selectedSetting_whenNotSpecified_isInitial() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        let emitted = try await self.selectedSetting(of: viewModel)

        // then
        #expect(emitted == TodayStyleSetting.initial)
    }
}


// MARK: - 편집·저장

extension WidgetStyleEditViewModelImpleTests {

    @Test("변형 하나만 주면 그 변형의 스타일만 목록에 선다")
    func refresh_withSingleVariant_listsOnlyItsStyles() async throws {
        // given
        let usecase = self.makeUsecase(saved: [
            self.todayStyle(.default),
            self.todayStyle(.custom(id: "m1"), variant: .monthSmall)
        ])
        let viewModel = WidgetStyleEditViewModelImple(
            variants: [.todaySummarySmall], widgetStyleUsecase: usecase
        )

        // when
        viewModel.refresh()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.map { $0.styleId.variant } == [.todaySummarySmall])
    }

    @Test("변형 둘을 주면 두 변형의 스타일이 순서대로 이어진다")
    func refresh_withTwoVariants_concatenatesInGivenOrder() async throws {
        // given
        let usecase = self.makeUsecase(saved: [
            self.todayStyle(.default),
            self.todayStyle(.custom(id: "c1"), name: "여름"),
            self.todayStyle(.default, variant: .monthSmall),
            self.todayStyle(.custom(id: "m1"), variant: .monthSmall, name: "달력")
        ])
        let viewModel = WidgetStyleEditViewModelImple(
            variants: [.todaySummarySmall, .monthSmall], widgetStyleUsecase: usecase
        )

        // when
        viewModel.refresh()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.map { $0.styleId.variant } == [
            .todaySummarySmall, .todaySummarySmall, .monthSmall, .monthSmall
        ])
        #expect(emitted.map { $0.name }.last == "달력")
    }

    @Test("스타일을 공유하는 변형군을 주면 목록이 한 벌만 선다")
    func refresh_withSharingVariants_listsStylesOnce() async throws {
        // given
        let usecase = self.makeUsecase(saved: [
            self.weekEventsStyle(.default),
            self.weekEventsStyle(.custom(id: "w1"), name: "주간")
        ])
        let viewModel = WidgetStyleEditViewModelImple(
            variants: [
                .oneWeekEvents, .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
                .currentMonthEvents, .lastMonthEvents, .nextMonthEvents
            ],
            widgetStyleUsecase: usecase
        )

        // when
        viewModel.refresh()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.map { $0.styleId.style } == [.default, .custom(id: "w1")])
        #expect(emitted.map { $0.name }.last == "주간")
    }

    @Test("추가 카드를 누르면 목록 맨 앞 스타일을 본떠 새 카드가 선다")
    func addStyle_copiesFirstStyle() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithCustom(name: "여름")

        // when
        viewModel.addStyle()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.count == 3)
        #expect(emitted.last?.name == "widget.style::custom::copy_format".localized(
            with: "widget.style::default".localized()
        ))
    }

    @Test("복제한 스타일은 원본과 같은 변형에 붙는다")
    func appendStyle_keepsVariantOfSource() async throws {
        // given
        let usecase = self.makeUsecase(saved: [
            self.todayStyle(.default),
            self.todayStyle(.default, variant: .monthSmall)
        ])
        let viewModel = WidgetStyleEditViewModelImple(
            variants: [.todaySummarySmall, .monthSmall], widgetStyleUsecase: usecase
        )
        viewModel.refresh()

        // when
        viewModel.appendStyle(copying: .init(variant: .monthSmall, style: .default))

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.last?.styleId.variant == .monthSmall)
    }

    @Test("꾸미기 대상이 아닌 변형으로 열면 카드 목록이 빈다")
    func refresh_whenVariantHasNoSettingType_emitsEmptyList() async throws {
        // given
        let expect = self.expectConfirm("빈 카드 목록이 나온다")
        let usecase = self.makeUsecase(saved: [self.todayStyle(.default)])
        let viewModel = WidgetStyleEditViewModelImple(
            variants: [.monthSmall], widgetStyleUsecase: usecase
        )

        // when
        let emitted = try await self.firstOutput(expect, for: viewModel.styles) {
            viewModel.refresh()
        }

        // then
        #expect(emitted?.isEmpty == true)
        #expect(usecase.updatedStyles.isEmpty == true)
    }

    @Test("스펙과 다른 타입의 설정이 오면 편집분이 바뀌지 않는다")
    func updateSetting_whenDifferentPayloadType_keepsEditing() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.updateSetting(OtherWidgetStyleSetting.initial)

        // then
        let emitted = try await self.selectedSetting(of: viewModel)
        #expect(emitted == TodayStyleSetting.initial)
    }

    @Test("설정을 바꾸면 고른 카드에만 반영되고 저장 전에는 저장소로 가지 않는다")
    func updateSetting_notSaveUntilConfirm() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.updateSetting(self.settingTurningOff(.showTimeZone))

        // then
        let emitted = try await self.selectedSetting(of: viewModel)
        #expect(emitted?.showTimeZone == false)
        #expect(usecase.updatedStyles.isEmpty)
    }

    @Test("저장하면 조작한 설정이 고른 스타일 좌표로 가고 화면은 그대로 남는다")
    func confirm_saveToggledSettingToSelectedStyle() {
        // given
        let router = SpyWidgetStyleEditRouter()
        let (viewModel, usecase) = self.makeViewModelSelectingCustom(router: router)

        // when
        viewModel.updateSetting(self.settingTurningOff(.showScheduleCount))
        viewModel.confirm()

        // then
        let saved = usecase.updatedStyles.first
        #expect((saved?.setting as? TodayStyleSetting)?.showScheduleCount == false)
        #expect((saved?.setting as? TodayStyleSetting)?.showHolidayName == true)
        #expect(saved?.id == self.customId)
        #expect(router.didClosed == nil)
    }

    @Test("저장하면 바꾼 이름이 설정과 함께 저장된다")
    func confirm_savesEditedNameWithSetting() {
        // given
        let (viewModel, usecase) = self.makeViewModelSelectingCustom(name: "밤 모드")
        viewModel.editName("낮 모드")

        // when
        viewModel.confirm()

        // then
        let saved = usecase.updatedStyles.first
        #expect(saved?.name == "낮 모드")
        #expect(saved?.id.style == .custom(id: "c1"))
    }

    @Test("바꾼 게 없으면 저장을 눌러도 아무 일도 없다")
    func confirm_whenNothingChanged_doesNothing() {
        // given
        let router = SpyWidgetStyleEditRouter()
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly(router: router)

        // when
        viewModel.confirm()

        // then
        #expect(usecase.updatedStyles.isEmpty)
        #expect(router.didClosed == nil)
    }

    @Test("저장은 고른 카드만 반영하고 다른 카드 편집분은 남긴다")
    func confirm_savesOnlySelectedStyle() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithEditOnBothCards()

        // when
        viewModel.confirm()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(usecase.updatedStyles.map { $0.id.style } == [.custom(id: "c1")])
        #expect(emitted.first?.hasUnsavedChange == true)
        #expect((emitted.first?.setting as? TodayStyleSetting)?.showTodoCount == false)
        #expect(emitted.last?.hasUnsavedChange == false)
    }

    @Test("고른 카드는 편집 중인 설정을 그린다")
    func styles_selectedCardShowsEditingSetting() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.updateSetting(self.settingTurningOff(.showTotalCount))

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect((emitted.first?.setting as? TodayStyleSetting)?.showTotalCount == false)
    }
}


// MARK: - 카드 추가·복사 — 저장 전까지는 초안

extension WidgetStyleEditViewModelImpleTests {

    @Test("카드를 추가하면 목록에 붙고 그 카드가 선택된다")
    func appendStyle_addsDraftCardAndSelectsIt() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly(showHolidayName: false)

        // when
        viewModel.appendStyle(copying: self.defaultId)

        // then
        let emitted = try await self.styles(of: viewModel)
        let selected = try await self.selectedStyleId(of: viewModel)
        #expect(emitted.count == 2)
        #expect((emitted.last?.setting as? TodayStyleSetting)?.showHolidayName == false)
        #expect(selected == emitted.last?.styleId)
        #expect(selected?.style != .default)
    }

    @Test("카드를 추가해도 저장소로는 가지 않는다")
    func appendStyle_doesNotReachStorage() {
        // given
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.appendStyle(copying: self.defaultId)

        // then
        #expect(usecase.updatedStyles.isEmpty)
        #expect(usecase.stubStyles.count == 1)
    }

    @Test("추가한 카드 이름은 원본 이름에 복사 표시를 붙인다")
    func appendStyle_namesAfterSourceWithCopySuffix() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithCustom(name: "밤 모드")

        // when
        viewModel.appendStyle(copying: self.customId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.last?.name == "widget.style::custom::copy_format".localized(with: "밤 모드"))
    }

    @Test("기본 카드에서 추가하면 기본 이름에 복사 표시를 붙인다")
    func appendStyle_copyingDefault_namesAfterDefaultLabel() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.appendStyle(copying: self.defaultId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(
            emitted.last?.name
            == "widget.style::custom::copy_format".localized(
                with: "widget.style::default".localized()
            )
        )
    }

    @Test("복사 이름이 이미 있으면 뒤에 번호를 붙인다")
    func appendStyle_whenCopyNameTaken_appendsNumber() async throws {
        // given
        let copied = "widget.style::custom::copy_format".localized(with: "밤 모드")
        let (viewModel, _) = self.makeViewModel(saved: [
            self.todayStyle(.default),
            self.todayStyle(.custom(id: "c1"), name: "밤 모드"),
            self.todayStyle(.custom(id: "c2"), name: copied)
        ])

        // when
        viewModel.appendStyle(copying: self.customId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.last?.name == "\(copied) 2")
    }

    @Test("같은 카드를 연달아 복사하면 번호가 하나씩 올라간다")
    func appendStyle_repeatedly_incrementsNumber() async throws {
        // given
        let copied = "widget.style::custom::copy_format".localized(with: "밤 모드")
        let (viewModel, _) = self.makeViewModelWithCustom(name: "밤 모드")

        // when
        viewModel.appendStyle(copying: self.customId)
        viewModel.appendStyle(copying: self.customId)
        viewModel.appendStyle(copying: self.customId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.map { $0.name }.suffix(3) == [copied, "\(copied) 2", "\(copied) 3"])
    }

    @Test("카드를 복사하면 원본 설정이 그대로 실린다")
    func appendStyle_copyingCustom_carriesSourceSetting() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithCustom(name: "밤 모드", showHolidayName: true)

        // when
        viewModel.appendStyle(copying: self.customId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect((emitted.last?.setting as? TodayStyleSetting)?.showHolidayName == true)
        #expect(emitted.last?.styleId != self.customId)
    }
}


// MARK: - 카드 전환은 편집분을 잃지 않는다

extension WidgetStyleEditViewModelImpleTests {

    @Test("카드를 바꿀 때는 묻지 않는다")
    func selectStyle_neverAsks() {
        // given
        let router = SpyWidgetStyleEditRouter()
        let (viewModel, _) = self.makeViewModelWithEdit(router: router)

        // when
        viewModel.selectStyle(self.customId)

        // then
        #expect(router.didShowActionSheetWith == nil)
    }

    @Test("카드를 옮겼다 돌아와도 편집분이 남아 있다")
    func selectStyle_keepsEditOfLeftCard() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithEdit()

        // when
        viewModel.selectStyle(self.customId)
        viewModel.selectStyle(self.defaultId)

        // then
        let emitted = try await self.selectedSetting(of: viewModel)
        #expect(emitted?.showTodoCount == false)
    }
}


// MARK: - 미저장 표시

extension WidgetStyleEditViewModelImpleTests {

    @Test("바꾼 게 없으면 미저장 표시가 없다")
    func hasUnsavedChange_whenUntouched_isFalse() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        let emitted = try await self.hasUnsavedChange(of: viewModel)

        // then
        #expect(emitted == false)
    }

    @Test("항목을 바꾸면 미저장 표시가 켜진다")
    func hasUnsavedChange_whenToggled_isTrue() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.updateSetting(self.settingTurningOff(.showTodoCount))

        // then
        let emitted = try await self.hasUnsavedChange(of: viewModel)
        #expect(emitted == true)
    }

    @Test("다른 카드만 바뀌었으면 하단 버튼은 꺼져 있다")
    func hasUnsavedChange_whenOtherCardEdited_isFalse() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithEdit()

        // when
        viewModel.selectStyle(self.customId)

        // then
        let emitted = try await self.hasUnsavedChange(of: viewModel)
        #expect(emitted == false)
    }

    @Test("고르지 않은 카드가 바뀌어도 이탈 잠금은 걸린다")
    func hasAnyUnsavedEdit_whenOtherCardEdited_isTrue() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithEdit()

        // when
        viewModel.selectStyle(self.customId)

        // then
        let emitted = try await self.hasAnyUnsavedEdit(of: viewModel)
        #expect(emitted == true)
    }

    @Test("바뀐 카드에만 미저장 점이 붙는다")
    func styles_markOnlyChangedCard() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithCustom()

        // when
        viewModel.updateSetting(self.settingTurningOff(.showTodoCount))

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.map { $0.hasUnsavedChange } == [true, false])
    }

    @Test("추가한 카드는 저장 전까지 미저장 점이 붙는다")
    func styles_markAppendedCardAsUnsaved() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.appendStyle(copying: self.defaultId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.map { $0.hasUnsavedChange } == [false, true])
    }
}


// MARK: - 화면 이탈

extension WidgetStyleEditViewModelImpleTests {

    @Test("편집분이 없으면 묻지 않고 화면이 닫힌다")
    func close_whenNotEdited_closesWithoutAsking() {
        // given
        let router = SpyWidgetStyleEditRouter()
        let (viewModel, _) = self.makeViewModelWithDefaultOnly(router: router)

        // when
        viewModel.close()

        // then
        #expect(router.didShowActionSheetWith == nil)
        #expect(router.didClosed == true)
    }

    @Test("편집 중 닫으면 저장 여부를 묻는다")
    func close_whenEdited_asksToSave() {
        // given
        let router = SpyWidgetStyleEditRouter()
        let (viewModel, _) = self.makeViewModelWithEdit(router: router)

        // when
        viewModel.close()

        // then
        #expect(router.didShowActionSheetWith?.actions.map { $0.text } == [
            "widget.style.edit::unsaved::save".localized(),
            "widget.style.edit::unsaved::discard".localized(),
            "common.cancel".localized()
        ])
        #expect(router.didClosed == nil)
    }

    @Test("닫기에서 저장을 고르면 저장하고 닫는다")
    func close_whenSaveChosen_savesThenCloses() {
        // given
        let router = SpyWidgetStyleEditRouter()
        self.mockSheetSelection(router, key: "widget.style.edit::unsaved::save")
        let (viewModel, usecase) = self.makeViewModelWithEdit(router: router)

        // when
        viewModel.close()

        // then
        let saved = usecase.updatedStyles.first
        #expect((saved?.setting as? TodayStyleSetting)?.showTodoCount == false)
        #expect(router.didClosed == true)
    }

    @Test("닫기에서 저장을 고르면 초안으로 만든 카드도 함께 저장된다")
    func close_whenSaveChosen_savesDraftCardsToo() {
        // given
        let router = SpyWidgetStyleEditRouter()
        self.mockSheetSelection(router, key: "widget.style.edit::unsaved::save")
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly(router: router)
        viewModel.appendStyle(copying: self.defaultId)

        // when
        viewModel.close()

        // then
        let savedIds = usecase.updatedStyles.map { $0.id.style }
        #expect(savedIds.count == 1)
        #expect(savedIds.first != .default)
    }

    @Test("닫기에서 버리기를 고르면 저장하지 않고 닫는다")
    func close_whenDiscardChosen_closesWithoutSaving() {
        // given
        let router = SpyWidgetStyleEditRouter()
        self.mockSheetSelection(router, key: "widget.style.edit::unsaved::discard")
        let (viewModel, usecase) = self.makeViewModelWithEdit(router: router)

        // when
        viewModel.close()

        // then
        #expect(usecase.updatedStyles.isEmpty)
        #expect(router.didClosed == true)
    }

    @Test("닫기에서 취소를 고르면 저장도 닫기도 하지 않는다")
    func close_whenCancelChosen_staysOnScreen() {
        // given
        let router = SpyWidgetStyleEditRouter()
        self.mockSheetSelection(router, key: "common.cancel")
        let (viewModel, usecase) = self.makeViewModelWithEdit(router: router)

        // when
        viewModel.close()

        // then
        #expect(usecase.updatedStyles.isEmpty)
        #expect(router.didClosed == nil)
    }

    @Test("저장하고 나면 미저장 표시가 사라진다")
    func hasUnsavedChange_afterSave_isFalse() async throws {
        // given
        let router = SpyWidgetStyleEditRouter()
        self.mockSheetSelection(router, key: "widget.style.edit::unsaved::save")
        let (viewModel, _) = self.makeViewModelWithEdit(router: router)

        // when
        viewModel.close()

        // then
        let emitted = try await self.hasUnsavedChange(of: viewModel)
        #expect(emitted == false)
    }
}


// MARK: - 되돌리기·초기화

extension WidgetStyleEditViewModelImpleTests {

    @Test("되돌리면 고른 카드가 저장된 값으로 돌아간다")
    func discard_restoresSavedStyles() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly(showHolidayName: true)
        viewModel.updateSetting(self.settingTurningOff(.showTodoCount))

        // when
        viewModel.discard()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect((emitted.first?.setting as? TodayStyleSetting)?.showTodoCount == true)
        #expect((emitted.first?.setting as? TodayStyleSetting)?.showHolidayName == true)
        #expect(usecase.updatedStyles.isEmpty)
    }

    @Test("되돌리기는 고른 카드만 되돌리고 다른 카드 편집분은 남긴다")
    func discard_restoresOnlySelectedStyle() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithEditOnBothCards()

        // when
        viewModel.discard()

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect((emitted.last?.setting as? TodayStyleSetting)?.showScheduleCount == true)
        #expect(emitted.last?.hasUnsavedChange == false)
        #expect((emitted.first?.setting as? TodayStyleSetting)?.showTodoCount == false)
        #expect(emitted.first?.hasUnsavedChange == true)
    }

    @Test("되돌리면 초안으로 만든 카드가 사라지고 선택도 옮겨간다")
    func discard_dropsDraftCardsAndMovesSelection() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()
        viewModel.appendStyle(copying: self.defaultId)

        // when
        viewModel.discard()

        // then
        let emitted = try await self.styles(of: viewModel)
        let selected = try await self.selectedStyleId(of: viewModel)
        #expect(emitted.count == 1)
        #expect(selected?.style == .default)
    }

    @Test("되돌린 뒤에는 미저장 표시가 사라진다")
    func discard_clearsUnsavedMark() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()
        viewModel.updateSetting(self.settingTurningOff(.showTodoCount))

        // when
        viewModel.discard()

        // then
        let emitted = try await self.hasUnsavedChange(of: viewModel)
        #expect(emitted == false)
    }

    @Test("되돌리면 입력 중이던 이름도 저장된 이름으로 돌아간다")
    func discard_restoresEditingName() async throws {
        // given
        let (viewModel, _) = self.makeViewModelSelectingCustom(name: "밤 모드")
        viewModel.editName("낮 모드")

        // when
        viewModel.discard()

        // then
        let emitted = try await self.editingName(of: viewModel)
        #expect(emitted == "밤 모드")
    }

    @Test("초기화하면 입력 중이던 이름도 비워진다")
    func resetStyle_clearsEditingName() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly(name: "손댄 기본")

        // when
        viewModel.resetStyle(self.defaultId)

        // then
        let emitted = try await self.editingName(of: viewModel)
        #expect(emitted == "")
    }

    @Test("기본 스타일을 초기화하면 설정이 코드 기본값으로 돌아간다")
    func resetStyle_restoresCodeDefaults() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly(showHolidayName: false)

        // when
        viewModel.resetStyle(self.defaultId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.first?.setting as? TodayStyleSetting == TodayStyleSetting.initial)
    }

    @Test("초기화도 저장을 눌러야 저장소에 반영된다")
    func resetStyle_doesNotReachStorageUntilSaved() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly(showHolidayName: false)

        // when
        viewModel.resetStyle(self.defaultId)

        // then
        let emitted = try await self.hasUnsavedChange(of: viewModel)
        #expect(usecase.updatedStyles.isEmpty)
        #expect(emitted == true)
    }

    @Test("초기화를 취소하면 설정이 그대로다")
    func resetStyle_whenConfirmCanceled_keepsSetting() async throws {
        // given
        let router = SpyWidgetStyleEditRouter()
        router.shouldConfirmNotCancel = false
        let (viewModel, _) = self.makeViewModelWithDefaultOnly(
            showHolidayName: false, router: router
        )

        // when
        viewModel.resetStyle(self.defaultId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect((emitted.first?.setting as? TodayStyleSetting)?.showHolidayName == false)
    }
}


// MARK: - 이름 변경·삭제

extension WidgetStyleEditViewModelImpleTests {

    @Test("이름을 바꾸면 카드 라벨이 따라 바뀐다")
    func editName_updatesCardLabel() async throws {
        // given
        let (viewModel, _) = self.makeViewModelSelectingCustom(name: "밤 모드")

        // when
        viewModel.editName("낮 모드")

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.last?.name == "낮 모드")
    }

    @Test("카드를 고르면 그 카드의 이름이 입력 값으로 나온다")
    func editingName_followsSelectedCard() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithCustom(name: "밤 모드")

        // when
        let emitted = try await self.editingNames(of: viewModel, count: 2) {
            viewModel.selectStyle(self.customId)
        }

        // then
        #expect(emitted == ["", "밤 모드"])
    }

    @Test("이름을 입력하는 동안에는 입력 값을 되돌려보내지 않는다")
    func editingName_whileTyping_doesNotEchoBack() async throws {
        // given
        let (viewModel, _) = self.makeViewModelSelectingCustom(name: "밤 모드")

        // when
        let emitted = try await self.editingNames(of: viewModel, count: 1) {
            viewModel.editName("낮")
            viewModel.editName("낮 모")
        }

        // then
        #expect(emitted == ["밤 모드"])
    }

    @Test("이름을 비우면 카드 라벨이 기본 문구로 돌아간다")
    func editName_whenBlank_fallsBackToUnnamedLabel() async throws {
        // given
        let (viewModel, _) = self.makeViewModelSelectingCustom(name: "밤 모드")

        // when
        viewModel.editName("   ")

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.last?.name == "widget.style::custom::unnamed".localized())
    }

    @Test("저장된 커스텀 스타일을 지우면 저장소에서도 지운다")
    func removeStyle_whenSaved_reachesStorage() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithCustom(name: "밤 모드")

        // when
        viewModel.removeStyle(self.customId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(usecase.removedStyleIds == [self.customId])
        #expect(emitted.map { $0.styleId } == [self.defaultId])
    }

    @Test("저장된 적 없는 초안 카드를 지우면 저장소를 건드리지 않는다")
    func removeStyle_whenDraft_doesNotReachStorage() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly()
        viewModel.appendStyle(copying: self.defaultId)
        let draftId = try #require(try await self.styles(of: viewModel).last?.styleId)

        // when
        viewModel.removeStyle(draftId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(usecase.removedStyleIds.isEmpty)
        #expect(emitted.count == 1)
    }

    @Test("선택 중인 카드를 지우면 첫 카드가 선택된다")
    func removeStyle_whenSelected_fallsBackToFirstCard() async throws {
        // given
        let (viewModel, _) = self.makeViewModelSelectingCustom()

        // when
        viewModel.removeStyle(self.customId)

        // then
        let selected = try await self.selectedStyleId(of: viewModel)
        #expect(selected?.style == .default)
    }

    @Test("삭제를 취소하면 스타일이 남는다")
    func removeStyle_whenConfirmCanceled_keepsStyle() async throws {
        // given
        let router = SpyWidgetStyleEditRouter()
        router.shouldConfirmNotCancel = false
        let (viewModel, usecase) = self.makeViewModelWithCustom(router: router)

        // when
        viewModel.removeStyle(self.customId)

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(usecase.removedStyleIds.isEmpty)
        #expect(emitted.count == 2)
    }

    @Test("고르지 않은 카드를 지워도 선택은 그대로다")
    func removeStyle_whenNotSelected_keepsSelection() async throws {
        // given
        let secondId = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c2"))
        let (viewModel, _) = self.makeViewModel(saved: [
            self.todayStyle(.default),
            self.todayStyle(.custom(id: "c1")),
            self.todayStyle(.custom(id: "c2"))
        ])
        viewModel.selectStyle(secondId)

        // when
        viewModel.removeStyle(self.customId)

        // then
        let selected = try await self.selectedStyleId(of: viewModel)
        #expect(selected == secondId)
    }
}


// MARK: - 배경색

extension WidgetStyleEditViewModelImpleTests {

    @Test("색을 안 고른 스타일은 배경색이 비어 있다 — 전역 설정을 따른다")
    func refresh_whenStyleHasNoBackground_selectedBackgroundIsNil() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        let emitted = try await self.selectedBackground(of: viewModel)

        // then
        #expect(emitted == .some(nil))
    }

    @Test("저장된 배경색이 있으면 고른 카드의 그 색이 흘러나온다")
    func selectStyle_emitsBackgroundOfThatCard() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(
            saved: [
                self.todayStyle(.default, background: .custom(hex: "#ffffff")),
                self.todayStyle(.custom(id: "c1"), background: .custom(hex: "#101820"))
            ]
        )

        // when
        viewModel.selectStyle(self.customId)
        let emitted = try await self.selectedBackground(of: viewModel)

        // then
        #expect(emitted == .custom(hex: "#101820"))
    }

    @Test("색을 고르면 그 스타일이 전역을 따르지 않게 된다")
    func updateBackground_selectedBackgroundBecomesCustom() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.updateBackground("#101820")
        let emitted = try await self.selectedBackground(of: viewModel)

        // then
        #expect(emitted == .custom(hex: "#101820"))
    }

    @Test("색을 고르면 미저장 표시가 켜진다")
    func updateBackground_marksUnsavedChange() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()

        // when
        viewModel.updateBackground("#101820")

        // then
        let emitted = try await self.hasUnsavedChange(of: viewModel)
        #expect(emitted == true)
    }

    @Test("색은 고른 카드에만 실리고 저장 전에는 저장소로 가지 않는다")
    func updateBackground_appliesToSelectedCardOnly() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithCustom()

        // when
        viewModel.updateBackground("#101820")

        // then
        let emitted = try await self.styles(of: viewModel)
        #expect(emitted.map { $0.background } == [.custom(hex: "#101820"), nil])
        #expect(usecase.updatedStyles.isEmpty)
    }

    @Test("저장하면 고른 색이 스타일과 함께 저장된다")
    func confirm_savesBackgroundWithStyle() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModelWithDefaultOnly()
        viewModel.updateBackground("#101820")

        // when
        viewModel.confirm()

        // then
        #expect(usecase.updatedStyles.map { $0.background } == [.custom(hex: "#101820")])
    }

    @Test("되돌리면 색도 전역 따름으로 돌아간다")
    func resetStyle_clearsBackground() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(
            saved: [self.todayStyle(.default, background: .custom(hex: "#101820"))]
        )

        // when
        viewModel.resetStyle(self.defaultId)
        let emitted = try await self.selectedBackground(of: viewModel)

        // then
        #expect(emitted == .some(nil))
    }

    @Test("색을 걸었다 되돌리면 그 카드가 다시 전역을 따른다")
    func resetStyle_afterUpdateBackground_followsGlobalAgain() async throws {
        // given
        let (viewModel, _) = self.makeViewModelWithDefaultOnly()
        viewModel.updateBackground("#101820")

        // when
        viewModel.resetStyle(self.defaultId)
        let emitted = try await self.selectedBackground(of: viewModel)

        // then
        #expect(emitted == .some(nil))
        let styles = try await self.styles(of: viewModel)
        #expect(styles.first?.background == nil)
    }

    @Test("카드를 복제하면 원본 배경색도 그대로 실린다")
    func appendStyle_copiesBackground() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(
            saved: [self.todayStyle(.default, background: .custom(hex: "#101820"))]
        )

        // when
        viewModel.appendStyle(copying: self.defaultId)
        let emitted = try await self.selectedBackground(of: viewModel)

        // then
        #expect(emitted == .custom(hex: "#101820"))
    }
}
