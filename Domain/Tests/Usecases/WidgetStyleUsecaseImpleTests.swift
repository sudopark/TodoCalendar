//
//  WidgetStyleUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


struct WidgetStyleUsecaseImpleTests {

    private final class StubRepository: WidgetStyleRepository, @unchecked Sendable {

        private let savedStyles: [WidgetStyle<TodayStyleSetting>]
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
            return self.savedStyles as? [WidgetStyle<S>] ?? []
        }

        func updateStyle<S: WidgetStyleSetting>(_ style: WidgetStyle<S>) {
            guard let updated = style as? WidgetStyle<TodayStyleSetting> else { return }
            self.updatedStyles.append(updated)
        }

        func removeStyle(_ id: WidgetStyleId) {
            self.removedStyleIds.append(id)
        }
    }

    private func todayStyle(
        _ style: WidgetStyleId.Style, name: String? = nil, showHolidayName: Bool?
    ) -> WidgetStyle<TodayStyleSetting> {
        return .init(
            id: .init(variant: .todaySummarySmall, style: style),
            name: name,
            setting: TodayStyleSetting() |> \.showHolidayName .~ showHolidayName
        )
    }

    private func makeUsecase(with repository: StubRepository) -> WidgetStyleUsecaseImple {
        return WidgetStyleUsecaseImple(styleRepository: repository)
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
        usecase.removeStyle(styleId)

        // then
        #expect(repository.removedStyleIds == [styleId])
    }

    @Test("기본 스타일은 삭제 요청이 저장소로 가지 않는다")
    func removeStyle_whenDefault_doesNotReachRepository() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)

        // when
        usecase.removeStyle(.init(variant: .todaySummarySmall, style: .default))

        // then
        #expect(repository.removedStyleIds.isEmpty)
    }
}
