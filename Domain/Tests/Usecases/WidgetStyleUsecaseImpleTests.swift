//
//  WidgetStyleUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Combine
import Prelude
import Optics
import UnitTestHelpKit

@testable import Domain


private struct OtherStyleSetting: WidgetStyleSetting {

    var isOn: Bool

    static let initial = OtherStyleSetting(isOn: true)
}


final class WidgetStyleUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let sharedDataStore: SharedDataStore = .init()

    private final class StubRepository: WidgetStyleRepository, @unchecked Sendable {

        private var savedStyles: [WidgetStyle]
        init(savedStyles: [WidgetStyle] = []) {
            self.savedStyles = savedStyles
        }

        func loadStyle(for id: WidgetStyleId) -> WidgetStyle? {
            return self.savedStyles.first { $0.id == id }
        }

        func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] {
            return self.savedStyles.filter { $0.id.variant == variant }
        }

        func updateStyle(_ style: WidgetStyle) {
            self.savedStyles = self.savedStyles.filter { $0.id != style.id } + [style]
        }

        func removeStyle(_ id: WidgetStyleId) {
            self.savedStyles = self.savedStyles.filter { $0.id != id }
        }
    }

    private func todayStyle(
        _ style: WidgetStyleId.Style,
        variant: WidgetVariant = .todaySummarySmall,
        name: String? = nil,
        showHolidayName: Bool,
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
        variant: WidgetVariant,
        name: String? = nil,
        showWeekDayHeader: Bool
    ) -> WidgetStyle {
        return .init(
            id: .init(variant: variant, style: style),
            name: name,
            setting: WeekEventsStyleSetting.initial |> \.showWeekDayHeader .~ showWeekDayHeader
        )
    }

    private func makeUsecase(with repository: StubRepository) -> WidgetStyleUsecaseImple {
        return WidgetStyleUsecaseImple(
            styleRepository: repository,
            sharedDataStore: self.sharedDataStore
        )
    }
}


// MARK: - 목록 조회

extension WidgetStyleUsecaseImpleTests {

    @Test("저장된 스타일이 없으면 초기 설정을 담은 기본 스타일 하나를 낸다")
    func loadStyles_whenNothingSaved_returnDefaultStyleWithInitialSetting() {
        // given
        let usecase = self.makeUsecase(with: .init())

        // when
        let styles = usecase.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.count == 1)
        #expect(styles.first?.id == .init(variant: .todaySummarySmall, style: .default))
        #expect(styles.first?.name == nil)
        #expect(styles.first?.setting as? TodayStyleSetting == TodayStyleSetting.initial)
    }

    @Test("기본 스타일이 저장돼 있으면 그 저장값을 첫 원소로 쓰고 덧붙이지 않는다")
    func loadStyles_whenDefaultSaved_returnSavedDefaultAsFirst() {
        // given
        let saved = self.todayStyle(.default, showHolidayName: false)
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        let styles = usecase.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.count == 1)
        #expect(styles.first?.setting.asToday?.showHolidayName == false)
    }

    @Test("커스텀 스타일만 저장돼 있으면 기본 스타일을 앞세우고 커스텀을 뒤에 붙인다")
    func loadStyles_whenOnlyCustomsSaved_prependDefaultStyle() {
        // given
        let customs = [
            self.todayStyle(.custom(id: "c1"), showHolidayName: true),
            self.todayStyle(.custom(id: "c2"), showHolidayName: false)
        ]
        let usecase = self.makeUsecase(with: .init(savedStyles: customs))

        // when
        let styles = usecase.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.id.style } == [.default, .custom(id: "c1"), .custom(id: "c2")])
        #expect(styles.first?.setting as? TodayStyleSetting == TodayStyleSetting.initial)
    }

    @Test("조회한 변형의 좌표로 목록이 선다")
    func loadStyles_returnsStylesOfGivenVariant() {
        // given
        let usecase = self.makeUsecase(with: .init())

        // when
        let styles = usecase.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.id } == [
            .init(variant: .todaySummarySmall, style: .default)
        ])
    }

    @Test("꾸미기 대상이 아닌 변형은 빈 목록을 낸다")
    func loadStyles_whenVariantHasNoSettingType_isEmpty() {
        // given
        let usecase = self.makeUsecase(with: .init())

        // when
        let styles = usecase.loadStyles(of: .doubleMonthMedium)

        // then
        #expect(styles.isEmpty == true)
    }

    @Test("저장분이 없어도 공유 변형 조회는 대표 좌표의 기본 스타일을 낸다")
    func loadStyles_fromSharingVariant_returnsRepresentativeCoordinate() {
        // given
        let usecase = self.makeUsecase(with: .init())

        // when
        let styles = usecase.loadStyles(of: .threeWeekEvents)

        // then
        #expect(styles.map { $0.id } == [.init(variant: .oneWeekEvents, style: .default)])
    }

    @Test("한 WeekEvents 변형으로 저장한 스타일이 다른 변형 조회에 그대로 나온다")
    func loadStyles_fromAnotherWeekEventsVariant_returnsSameSavedStyle() {
        // given
        let saved = self.weekEventsStyle(
            .custom(id: "c1"), variant: .twoWeekEvents, showWeekDayHeader: false
        )
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        let styles = usecase.loadStyles(of: .lastMonthEvents)

        // then
        #expect(styles.map { $0.id.style } == [.default, .custom(id: "c1")])
        #expect(
            (styles.last?.setting as? WeekEventsStyleSetting)?.showWeekDayHeader == false
        )
    }
}


// MARK: - 스타일 스트림

extension WidgetStyleUsecaseImpleTests {

    @Test("갱신 요청 전에는 스트림이 아무것도 내보내지 않는다")
    func styles_beforeRefresh_doesNotEmit() async throws {
        // given
        let expect = expectConfirm("갱신 전에는 방출이 없다")
        expect.count = 0
        expect.timeout = .milliseconds(300)
        let saved = self.todayStyle(.default, showHolidayName: false)
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        let styleLists = try await self.outputs(
            expect, for: usecase.styles(of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(of: .monthSmall)
        }

        // then
        #expect(styleLists.isEmpty == true)
    }

    @Test("갱신을 요청하면 저장된 스타일 목록을 내보낸다")
    func styles_afterRefresh_emitsStoredStyles() async throws {
        // given
        let expect = expectConfirm("저장된 목록이 나온다")
        let saved = [
            self.todayStyle(.default, showHolidayName: false),
            self.todayStyle(.custom(id: "c1"), showHolidayName: true)
        ]
        let usecase = self.makeUsecase(with: .init(savedStyles: saved))

        // when
        let styles = try await self.firstOutput(
            expect, for: usecase.styles(of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(of: .todaySummarySmall)
        }

        // then
        #expect(styles?.map { $0.id.style } == [.default, .custom(id: "c1")])
        #expect(styles?.first?.setting.asToday?.showHolidayName == false)
    }

    @Test("저장된 스타일이 없으면 갱신 후에도 기본 스타일 한 장만 낸다")
    func styles_whenNothingStored_emitsDefaultStyleOnly() async throws {
        // given
        let expect = expectConfirm("기본 스타일 한 장만 나온다")
        let usecase = self.makeUsecase(with: .init())

        // when
        let styles = try await self.firstOutput(
            expect, for: usecase.styles(of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(of: .todaySummarySmall)
        }

        // then
        #expect(styles?.map { $0.id.style } == [.default])
        #expect(styles?.first?.setting as? TodayStyleSetting == TodayStyleSetting.initial)
    }

    @Test("한 WeekEvents 변형으로 갱신하면 다른 변형 스트림도 같은 목록을 받는다")
    func styles_fromAnotherWeekEventsVariant_sharesOneStream() async throws {
        // given
        let expect = expectConfirm("공유 스트림이 목록을 낸다")
        let saved = self.weekEventsStyle(
            .default, variant: .oneWeekEvents, showWeekDayHeader: false
        )
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        let styles = try await self.firstOutput(
            expect, for: usecase.styles(of: .fourWeekEvents)
        ) {
            usecase.refreshStyles(of: .currentMonthEvents)
        }

        // then
        #expect(
            (styles?.first?.setting as? WeekEventsStyleSetting)?.showWeekDayHeader == false
        )
    }

    @Test("스타일을 저장하면 같은 변형 스트림이 갱신된 목록을 다시 낸다")
    func styles_afterUpdateStyle_emitsUpdatedList() async throws {
        // given
        let expect = expectConfirm("갱신된 목록이 다시 나온다")
        expect.count = 2
        let usecase = self.makeUsecase(with: .init())

        // when
        let styleLists = try await self.outputs(
            expect, for: usecase.styles(of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(of: .todaySummarySmall)
            usecase.updateStyle(self.todayStyle(.default, showHolidayName: false))
        }

        // then
        #expect(styleLists.map { $0.first?.setting.asToday?.showHolidayName } == [true, false])
    }

    @Test("커스텀 스타일을 지우면 그 스타일이 빠진 목록을 다시 낸다")
    func styles_afterRemoveStyle_emitsListWithoutRemoved() async throws {
        // given
        let expect = expectConfirm("지운 스타일이 빠진 목록이 나온다")
        expect.count = 2
        let custom = self.todayStyle(.custom(id: "c1"), showHolidayName: true)
        let usecase = self.makeUsecase(with: .init(savedStyles: [custom]))

        // when
        let styleLists = try await self.outputs(
            expect, for: usecase.styles(of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(of: .todaySummarySmall)
            usecase.removeStyle(custom.id)
        }

        // then
        #expect(styleLists.map { $0.map { $0.id.style } } == [
            [.default, .custom(id: "c1")], [.default]
        ])
    }

    @Test("기본 스타일 삭제 요청은 스트림을 다시 내보내지 않는다")
    func styles_whenRemoveDefaultStyle_doesNotEmitAgain() async throws {
        // given
        let expect = expectConfirm("기본 스타일 삭제는 재방출하지 않는다")
        expect.count = 2
        let custom = self.todayStyle(.custom(id: "c1"), showHolidayName: true)
        let usecase = self.makeUsecase(with: .init(savedStyles: [custom]))

        // when
        let styleLists = try await self.outputs(
            expect, for: usecase.styles(of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(of: .todaySummarySmall)
            usecase.removeStyle(.init(variant: .todaySummarySmall, style: .default))
            usecase.removeStyle(custom.id)
        }

        // then
        #expect(styleLists.map { $0.map { $0.id.style } } == [
            [.default, .custom(id: "c1")], [.default]
        ])
    }

    @Test("다른 변형을 갱신하면 이 변형 스트림은 다시 내보내지 않는다")
    func styles_whenOtherVariantUpdated_doesNotEmit() async throws {
        // given
        let expect = expectConfirm("다른 변형 갱신은 재방출하지 않는다")
        expect.count = 2
        let usecase = self.makeUsecase(with: .init())

        // when
        let styleLists = try await self.outputs(
            expect, for: usecase.styles(of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(of: .todaySummarySmall)
            usecase.updateStyle(
                self.todayStyle(.custom(id: "m1"), variant: .monthSmall, showHolidayName: true)
            )
            usecase.updateStyle(self.todayStyle(.default, showHolidayName: false))
        }

        // then
        #expect(styleLists.map { $0.map { $0.id.style } } == [[.default], [.default]])
        #expect(styleLists.map { $0.first?.setting.asToday?.showHolidayName } == [true, false])
    }
}


// MARK: - 갱신

extension WidgetStyleUsecaseImpleTests {

    @Test("갱신할 스타일을 저장소에 그대로 넘긴다")
    func updateStyle_passStyleToRepository() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)
        let style = self.todayStyle(.custom(id: "c1"), name: "밤 모드", showHolidayName: false)

        // when
        usecase.updateStyle(style)

        // then
        let saved = usecase.loadStyles(of: .todaySummarySmall).last
        #expect(saved?.isSame(style) == true)
    }

    @Test("좌표의 변형이 쓰는 타입이 아닌 설정은 저장소로 가지 않는다")
    func updateStyle_whenSettingTypeDoesNotMatchVariant_doesNotSave() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)
        let style = WidgetStyle(
            id: .init(variant: .todaySummarySmall, style: .custom(id: "c1")),
            name: "밤 모드",
            setting: OtherStyleSetting.initial
        )

        // when
        usecase.updateStyle(style)

        // then
        #expect(usecase.loadStyles(of: .todaySummarySmall).map { $0.id.style } == [.default])
    }

    @Test("비대표 WeekEvents 변형으로 저장해도 공유 좌표에 들어가 다른 변형이 읽는다")
    func updateStyle_fromAnyWeekEventsVariant_savesToSharedCoordinate() {
        // given
        let usecase = self.makeUsecase(with: .init())
        let style = self.weekEventsStyle(
            .custom(id: "c1"), variant: .twoWeekEvents, showWeekDayHeader: false
        )

        // when
        usecase.updateStyle(style)
        let styles = usecase.loadStyles(of: .lastMonthEvents)

        // then
        #expect(styles.map { $0.id } == [
            .init(variant: .oneWeekEvents, style: .default),
            .init(variant: .oneWeekEvents, style: .custom(id: "c1"))
        ])
        #expect(
            (styles.last?.setting as? WeekEventsStyleSetting)?.showWeekDayHeader == false
        )
    }

    @Test("공백뿐인 이름은 없는 것으로 저장된다")
    func updateStyle_whenNameIsBlank_savesWithoutName() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)
        let style = self.todayStyle(.custom(id: "c1"), name: "   ", showHolidayName: false)

        // when
        usecase.updateStyle(style)

        // then
        let saved = usecase.loadStyles(of: .todaySummarySmall).last
        #expect(saved?.name == nil)
        #expect(saved?.setting.asToday?.showHolidayName == false)
    }
}


// MARK: - 좌표 발급

extension WidgetStyleUsecaseImpleTests {

    @Test("새 좌표는 저장하지 않고 커스텀 좌표로만 내준다")
    func makeNewStyleId_mintsCustomCoordinateWithoutSaving() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)

        // when
        let newId = usecase.makeNewStyleId(for: .todaySummarySmall)

        // then
        #expect(newId.variant == .todaySummarySmall)
        #expect(newId.style != .default)
        #expect(usecase.loadStyles(of: .todaySummarySmall).map { $0.id } == [
            .init(variant: .todaySummarySmall, style: .default)
        ])
    }

    @Test("두 번 발급하면 서로 다른 좌표가 나온다")
    func makeNewStyleId_twice_mintsDistinctCoordinates() {
        // given
        let usecase = self.makeUsecase(with: .init())

        // when
        let first = usecase.makeNewStyleId(for: .todaySummarySmall)
        let second = usecase.makeNewStyleId(for: .todaySummarySmall)

        // then
        #expect(first != second)
    }
}


// MARK: - 삭제

extension WidgetStyleUsecaseImpleTests {

    @Test("커스텀 스타일을 지우면 목록에서 빠진다")
    func removeStyle_whenCustom_dropsItFromList() {
        // given
        let styleId = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))
        let saved = self.todayStyle(.custom(id: "c1"), showHolidayName: true)
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        usecase.removeStyle(styleId)

        // then
        #expect(usecase.loadStyles(of: .todaySummarySmall).map { $0.id.style } == [.default])
    }

    @Test("기본 스타일은 지워지지 않고 목록에 남는다")
    func removeStyle_whenDefault_keepsItInList() {
        // given
        let saved = self.todayStyle(.default, showHolidayName: false)
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        usecase.removeStyle(.init(variant: .todaySummarySmall, style: .default))

        // then
        let styles = usecase.loadStyles(of: .todaySummarySmall)
        #expect(styles.map { $0.id.style } == [.default])
        #expect(styles.first?.setting.asToday?.showHolidayName == false)
    }
}


private extension WidgetStyleSetting {

    var asToday: TodayStyleSetting? { self as? TodayStyleSetting }
}


// MARK: - 배경색

extension WidgetStyleUsecaseImpleTests {

    @Test("저장하면 고른 배경색과 다듬은 이름이 함께 실린다")
    func updateStyle_carriesBackgroundAndTrimmedName() {
        // given
        let usecase = self.makeUsecase(with: .init())

        // when
        usecase.updateStyle(
            self.todayStyle(
                .custom(id: "c1"), name: "  밤 모드  ", showHolidayName: false,
                background: .custom(hex: "#101820")
            )
        )

        // then
        let saved = usecase.loadStyles(of: .todaySummarySmall).last
        #expect(saved?.background == .custom(hex: "#101820"))
        #expect(saved?.name == "밤 모드")
    }

    @Test("저장한 배경색이 다시 조회한 목록에도 실린다")
    func loadStyles_afterUpdate_carriesBackground() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)
        usecase.updateStyle(
            self.todayStyle(
                .custom(id: "c1"), showHolidayName: false, background: .custom(hex: "#101820")
            )
        )

        // when
        let styles = usecase.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.background } == [nil, .custom(hex: "#101820")])
    }

    @Test("저장된 기본 스타일의 배경색도 첫 원소에 실린다")
    func loadStyles_whenDefaultSavedWithBackground_carriesIt() {
        // given
        let saved = self.todayStyle(
            .default, showHolidayName: false, background: .custom(hex: "#ffffff")
        )
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        let styles = usecase.loadStyles(of: .todaySummarySmall)

        // then
        #expect(styles.first?.background == .custom(hex: "#ffffff"))
    }
}
