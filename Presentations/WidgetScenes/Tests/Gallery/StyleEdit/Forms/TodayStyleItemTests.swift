//
//  TodayStyleItemTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain
import Extensions

@testable import WidgetScenes


struct TodayStyleItemTests {

    @Test("값이 상황을 타는 항목에만 부연 설명이 붙는다")
    func note_onlyForConditionalItems() {
        // given
        let items = TodayStyleItem.allCases

        // when
        let itemsHavingNote = items.filter { $0.note != nil }

        // then
        #expect(itemsHavingNote == [.showHolidayName, .showTimeZone])
    }

    @Test("항목마다 다른 설정 값을 가리킨다")
    func settingKeyPath_pointsDistinctValue() {
        // given
        let items = TodayStyleItem.allCases

        // when
        let keyPaths = items.map { $0.settingKeyPath }

        // then
        #expect(Set(keyPaths).count == items.count)
    }
}
