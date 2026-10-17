//
//  WeekEventsViewModelTests.swift
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


struct WeekEventsViewModelTests {

    private func makeModel(showWeekDayHeader: Bool) -> WeekEventsViewModel {
        let style = WeekEventsStyleSetting.initial
            |> \.showWeekDayHeader .~ showWeekDayHeader
        return WeekEventsViewModel.sample(.weeks(count: 1))
            |> \.look .~ .init(
                globalSetting: .init(),
                appliedStyle: .init(
                    id: .init(variant: .oneWeekEvents, style: .default),
                    name: nil, setting: style
                )
            )
    }
}


extension WeekEventsViewModelTests {

    @Test("초기 스타일은 요일 헤더를 그린다")
    func initialStyle_showsWeekDayHeader() {
        // given
        let model = WeekEventsViewModel.sample(.weeks(count: 1))

        // when + then
        #expect(model.showsWeekDayHeader == true)
    }

    @Test("요일 헤더를 끄면 그리지 않는다")
    func whenShowWeekDayHeaderOff_hidesHeader() {
        // given
        let model = self.makeModel(showWeekDayHeader: false)

        // when + then
        #expect(model.showsWeekDayHeader == false)
        #expect(model.orderedWeekDaysModel.isEmpty == false)
    }
}
