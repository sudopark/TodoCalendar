//
//  MonthWidgetViewModelTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Domain

@testable import WidgetScenes


struct MonthWidgetViewModelTests {

    private func makeModel(
        turningOff items: MonthStyleItem...
    ) throws -> MonthWidgetViewModel {
        let style = items.reduce(into: MonthStyleSetting.initial) { acc, item in
            acc[keyPath: item.settingKeyPath] = false
        }
        return try MonthWidgetViewModel.makeSample()
            |> \.look .~ .init(
                globalSetting: .init(),
                appliedStyle: .init(
                    id: .init(variant: .monthSmall, style: .default),
                    name: nil, setting: style
                )
            )
    }
}


extension MonthWidgetViewModelTests {

    @Test("초기 스타일은 표시 항목을 전부 그린다")
    func initialStyle_showsEveryItem() throws {
        // given
        let model = try self.makeModel()

        // when + then
        #expect(model.showsMonthName == true)
        #expect(model.showsWeekDayHeader == true)
        #expect(model.showsEventUnderline == true)
        #expect(model.highlightedTodayIdentifier == model.todayIdentifier)
    }

    @Test("월 이름을 끄면 그리지 않는다")
    func whenShowMonthNameOff_hidesMonthName() throws {
        // given
        let model = try self.makeModel(turningOff: .showMonthName)

        // when + then
        #expect(model.showsMonthName == false)
        #expect(model.showsWeekDayHeader == true)
    }

    @Test("요일 헤더를 끄면 그리지 않는다")
    func whenShowWeekDayHeaderOff_hidesHeader() throws {
        // given
        let model = try self.makeModel(turningOff: .showWeekDayHeader)

        // when + then
        #expect(model.showsWeekDayHeader == false)
        #expect(model.showsMonthName == true)
    }

    @Test("오늘 강조를 끄면 강조할 날이 없어 평일과 같아진다")
    func whenHighlightTodayOff_hasNoHighlightedDay() throws {
        // given
        let model = try self.makeModel(turningOff: .highlightToday)

        // when + then
        #expect(model.todayIdentifier != nil)
        #expect(model.highlightedTodayIdentifier == nil)
    }

    @Test("이벤트 밑줄을 끄면 그리지 않는다")
    func whenShowEventUnderlineOff_hidesUnderline() throws {
        // given
        let model = try self.makeModel(turningOff: .showEventUnderline)

        // when + then
        #expect(model.hasEventDaysIdentifiers.isEmpty == false)
        #expect(model.showsEventUnderline == false)
    }
}
