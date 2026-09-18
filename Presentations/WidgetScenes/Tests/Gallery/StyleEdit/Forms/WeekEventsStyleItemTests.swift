//
//  WeekEventsStyleItemTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain
import Extensions

@testable import WidgetScenes


struct WeekEventsStyleItemTests {

    @Test("항목이 늘 그려지는 요소라 부연 설명이 붙지 않는다")
    func note_isEmptyForAllItems() {
        // given
        let items = WeekEventsStyleItem.allCases

        // when
        let itemsHavingNote = items.filter { $0.note != nil }

        // then
        #expect(itemsHavingNote.isEmpty == true)
    }

    @Test("요일 헤더 항목 하나를 갖고 설정의 그 값을 가리킨다")
    func settingKeyPath_pointsWeekDayHeader() {
        // given
        let items = WeekEventsStyleItem.allCases

        // when + then
        #expect(items == [.showWeekDayHeader])
        #expect(
            WeekEventsStyleSetting.initial[
                keyPath: WeekEventsStyleItem.showWeekDayHeader.settingKeyPath
            ] == true
        )
    }
}
