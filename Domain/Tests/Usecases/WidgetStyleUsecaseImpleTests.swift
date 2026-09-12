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

        private let savedStyles: [Any]
        init(savedStyles: [Any] = []) {
            self.savedStyles = savedStyles
        }

        private(set) var requestedVariant: WidgetVariant?
        private(set) var updatedSetting: Any?
        private(set) var updatedStyleId: WidgetStyleId?

        func loadSetting<S: WidgetStyleSetting>(_ type: S.Type, for id: WidgetStyleId) -> S? {
            return nil
        }

        func loadStyles<S: WidgetStyleSetting>(
            _ type: S.Type, of variant: WidgetVariant
        ) -> [WidgetStyle<S>] {
            self.requestedVariant = variant
            return self.savedStyles.compactMap { $0 as? WidgetStyle<S> }
        }

        func updateSetting<S: WidgetStyleSetting>(_ setting: S, for id: WidgetStyleId) {
            self.updatedSetting = setting
            self.updatedStyleId = id
        }

        func removeStyle(_ id: WidgetStyleId) { }
    }

    private func todayStyle(
        _ style: WidgetStyleId.Style, showHolidayName: Bool?
    ) -> WidgetStyle<TodayStyleSetting> {
        return .init(
            id: .init(variant: .todaySummarySmall, style: style),
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

    @Test("갱신할 설정과 좌표를 저장소에 그대로 넘긴다")
    func updateStyle_passSettingAndIdToRepository() {
        // given
        let repository = StubRepository()
        let usecase = self.makeUsecase(with: repository)
        let setting = TodayStyleSetting() |> \.showTodoCount .~ false
        let styleId = WidgetStyleId(variant: .todaySummarySmall, style: .custom(id: "c1"))

        // when
        usecase.updateStyle(setting, for: styleId)

        // then
        #expect(repository.updatedSetting as? TodayStyleSetting == setting)
        #expect(repository.updatedStyleId == styleId)
    }
}
