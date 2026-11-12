//
//  WeekEventsViewModelTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import WidgetScenes
import SettingDomainInterface
import SettingDomainTesting


struct WeekEventsViewModelTests {

    private func makeModel(_ style: WeekEventsStyleSetting) -> WeekEventsViewModel {
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
        let model = self.makeModel(
            WeekEventsStyleSetting.initial |> \.showWeekDayHeader .~ false
        )

        // when + then
        #expect(model.showsWeekDayHeader == false)
        #expect(model.orderedWeekDaysModel.isEmpty == false)
    }
}


// MARK: - 일정 글자 크기

extension WeekEventsViewModelTests {

    @Test("일정 글자·줄 높이·축소 하한이 스타일의 글자 크기를 따른다", arguments: [
        (8, 10.0, 0.5), (9, 11.0, 0.65), (10, 12.0, 0.8)
    ])
    func eventMetrics_followStyleTextSize(
        textSize: Int, rowHeight: Double, minimumScale: Double
    ) {
        // given
        let model = self.makeModel(
            WeekEventsStyleSetting.initial |> \.eventTextSize .~ textSize
        )

        // when + then
        #expect(model.eventTextSize == CGFloat(textSize))
        #expect(model.eventRowHeightWithSpacing == CGFloat(rowHeight))
        #expect(abs(model.eventTextMinimumScaleFactor - CGFloat(minimumScale)) < 0.0001)
    }

    @Test("초기 스타일은 지금 모양(8pt·줄 10pt·축소 0.5)을 그대로 그린다")
    func eventMetrics_withInitialStyle_matchCurrentLook() {
        // given
        let model = WeekEventsViewModel.sample(.weeks(count: 1))

        // when + then
        #expect(model.eventTextSize == 8)
        #expect(model.eventRowHeightWithSpacing == 10)
        #expect(model.eventTextMinimumScaleFactor == 0.5)
    }
}
