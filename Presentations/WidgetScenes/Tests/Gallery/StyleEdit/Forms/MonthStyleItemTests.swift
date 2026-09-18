//
//  MonthStyleItemTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain
import Extensions

@testable import WidgetScenes


struct MonthStyleItemTests {

    @Test("항목이 전부 늘 그려지는 요소라 부연 설명이 붙지 않는다")
    func note_isEmptyForAllItems() {
        // given
        let items = MonthStyleItem.allCases

        // when
        let itemsHavingNote = items.filter { $0.note != nil }

        // then
        #expect(itemsHavingNote.isEmpty == true)
    }

    @Test("항목마다 다른 설정 값을 가리킨다")
    func settingKeyPath_pointsDistinctValue() {
        // given
        let items = MonthStyleItem.allCases

        // when
        let keyPaths = items.map { $0.settingKeyPath }

        // then
        #expect(Set(keyPaths).count == items.count)
        #expect(items.count == 4)
    }

    @Test("항목 순서는 위젯 뷰의 위에서 아래 순이다")
    func allCases_followViewOrder() {
        // when + then
        #expect(MonthStyleItem.allCases == [
            .showMonthName, .showWeekDayHeader, .highlightToday, .showEventUnderline
        ])
    }
}
