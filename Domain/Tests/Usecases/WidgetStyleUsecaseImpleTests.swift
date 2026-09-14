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


final class WidgetStyleUsecaseImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = .init()
    private let sharedDataStore: SharedDataStore = .init()

    private final class StubRepository: WidgetStyleRepository, @unchecked Sendable {

        private var savedStyles: [WidgetStyle<TodayStyleSetting>]
        init(savedStyles: [WidgetStyle<TodayStyleSetting>] = []) {
            self.savedStyles = savedStyles
        }

        private(set) var requestedVariant: WidgetVariant?
        private(set) var updatedStyles: [WidgetStyle<TodayStyleSetting>] = []
        private(set) var removedStyleIds: [WidgetStyleId] = []

        func loadSetting<S: WidgetStyleSetting>(_ type: S.Type, for id: WidgetStyleId) -> S? {
            return nil
        }

        func loadStyles<S: WidgetStyleSetting>(
            _ type: S.Type, of variant: WidgetVariant
        ) -> [WidgetStyle<S>] {
            self.requestedVariant = variant
            let styles = self.savedStyles.filter { $0.id.variant == variant }
            return styles as? [WidgetStyle<S>] ?? []
        }

        func updateStyle<S: WidgetStyleSetting>(_ style: WidgetStyle<S>) {
            guard let updated = style as? WidgetStyle<TodayStyleSetting> else { return }
            self.updatedStyles.append(updated)
            self.savedStyles = self.savedStyles.filter { $0.id != updated.id } + [updated]
        }

        func removeStyle(_ id: WidgetStyleId) {
            self.removedStyleIds.append(id)
            self.savedStyles = self.savedStyles.filter { $0.id != id }
        }
    }

    private func todayStyle(
        _ style: WidgetStyleId.Style,
        variant: WidgetVariant = .todaySummarySmall,
        name: String? = nil,
        showHolidayName: Bool?
    ) -> WidgetStyle<TodayStyleSetting> {
        return .init(
            id: .init(variant: variant, style: style),
            name: name,
            setting: TodayStyleSetting() |> \.showHolidayName .~ showHolidayName
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
        let styles = usecase.loadStyles(TodayStyleSetting.self, of: .todaySummarySmall)

        // then
        #expect(styles.count == 1)
        #expect(styles.first?.id == .init(variant: .todaySummarySmall, style: .default))
        #expect(styles.first?.name == nil)
        #expect(styles.first?.setting == TodayStyleSetting())
    }

    @Test("기본 스타일이 저장돼 있으면 그 저장값을 첫 원소로 쓰고 덧붙이지 않는다")
    func loadStyles_whenDefaultSaved_returnSavedDefaultAsFirst() {
        // given
        let saved = self.todayStyle(.default, showHolidayName: false)
        let usecase = self.makeUsecase(with: .init(savedStyles: [saved]))

        // when
        let styles = usecase.loadStyles(TodayStyleSetting.self, of: .todaySummarySmall)

        // then
        #expect(styles.count == 1)
        #expect(styles.first?.setting.showHolidayName == false)
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
        let styles = usecase.loadStyles(TodayStyleSetting.self, of: .todaySummarySmall)

        // then
        #expect(styles.map { $0.id.style } == [.default, .custom(id: "c1"), .custom(id: "c2")])
        #expect(styles.first?.setting == TodayStyleSetting())
    }

    @Test("조회한 변형을 저장소에 그대로 넘긴다")
    func loadStyles_passGivenVariantToRepository() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)

        // when
        let styles = usecase.loadStyles(TodayStyleSetting.self, of: .monthSmall)

        // then
        #expect(repository.requestedVariant == .monthSmall)
        #expect(styles.first?.id.variant == .monthSmall)
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
            expect, for: usecase.styles(TodayStyleSetting.self, of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(TodayStyleSetting.self, of: .monthSmall)
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
            expect, for: usecase.styles(TodayStyleSetting.self, of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(TodayStyleSetting.self, of: .todaySummarySmall)
        }

        // then
        #expect(styles?.map { $0.id.style } == [.default, .custom(id: "c1")])
        #expect(styles?.first?.setting.showHolidayName == false)
    }

    @Test("저장된 스타일이 없으면 갱신 후에도 기본 스타일 한 장만 낸다")
    func styles_whenNothingStored_emitsDefaultStyleOnly() async throws {
        // given
        let expect = expectConfirm("기본 스타일 한 장만 나온다")
        let usecase = self.makeUsecase(with: .init())

        // when
        let styles = try await self.firstOutput(
            expect, for: usecase.styles(TodayStyleSetting.self, of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(TodayStyleSetting.self, of: .todaySummarySmall)
        }

        // then
        #expect(styles?.map { $0.id.style } == [.default])
        #expect(styles?.first?.setting == TodayStyleSetting())
    }

    @Test("스타일을 저장하면 같은 변형 스트림이 갱신된 목록을 다시 낸다")
    func styles_afterUpdateStyle_emitsUpdatedList() async throws {
        // given
        let expect = expectConfirm("갱신된 목록이 다시 나온다")
        expect.count = 2
        let usecase = self.makeUsecase(with: .init())

        // when
        let styleLists = try await self.outputs(
            expect, for: usecase.styles(TodayStyleSetting.self, of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(TodayStyleSetting.self, of: .todaySummarySmall)
            usecase.updateStyle(self.todayStyle(.default, showHolidayName: true))
        }

        // then
        #expect(styleLists.map { $0.first?.setting.showHolidayName } == [nil, true])
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
            expect, for: usecase.styles(TodayStyleSetting.self, of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(TodayStyleSetting.self, of: .todaySummarySmall)
            usecase.removeStyle(TodayStyleSetting.self, custom.id)
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
            expect, for: usecase.styles(TodayStyleSetting.self, of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(TodayStyleSetting.self, of: .todaySummarySmall)
            usecase.removeStyle(
                TodayStyleSetting.self, .init(variant: .todaySummarySmall, style: .default)
            )
            usecase.removeStyle(TodayStyleSetting.self, custom.id)
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
            expect, for: usecase.styles(TodayStyleSetting.self, of: .todaySummarySmall)
        ) {
            usecase.refreshStyles(TodayStyleSetting.self, of: .todaySummarySmall)
            usecase.updateStyle(
                self.todayStyle(.custom(id: "m1"), variant: .monthSmall, showHolidayName: true)
            )
            usecase.updateStyle(self.todayStyle(.default, showHolidayName: false))
        }

        // then
        #expect(styleLists.map { $0.map { $0.id.style } } == [[.default], [.default]])
        #expect(styleLists.map { $0.first?.setting.showHolidayName } == [nil, false])
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
        let updated = repository.updatedStyles.first
        #expect(updated == style)
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
        let updated = repository.updatedStyles.first
        #expect(updated?.name == nil)
        #expect(updated?.setting.showHolidayName == false)
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
        #expect(repository.updatedStyles.isEmpty)
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

    @Test("커스텀 스타일 삭제 요청은 저장소로 그대로 간다")
    func removeStyle_whenCustom_passesIdToRepository() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)
        let styleId = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))

        // when
        usecase.removeStyle(TodayStyleSetting.self, styleId)

        // then
        #expect(repository.removedStyleIds == [styleId])
    }

    @Test("기본 스타일은 삭제 요청이 저장소로 가지 않는다")
    func removeStyle_whenDefault_doesNotReachRepository() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)

        // when
        usecase.removeStyle(
            TodayStyleSetting.self, .init(variant: .todaySummarySmall, style: .default)
        )

        // then
        #expect(repository.removedStyleIds.isEmpty)
    }
}
