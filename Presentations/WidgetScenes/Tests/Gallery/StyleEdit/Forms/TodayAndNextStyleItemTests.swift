//
//  TodayAndNextStyleItemTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import Extensions

@testable import WidgetScenes


struct TodayAndNextStyleItemTests {

    @Test("항목이 늘 그려지는 요소라 부연 설명이 붙지 않는다")
    func note_isEmptyForAllItems() {
        // given
        let items = TodayAndNextStyleItem.allCases

        // when
        let itemsHavingNote = items.filter { $0.note != nil }

        // then
        #expect(itemsHavingNote.isEmpty == true)
    }

    @Test("타임존 항목 하나를 갖고 설정의 그 값을 가리킨다")
    func settingKeyPath_pointsshowTimeZone() {
        // given
        let items = TodayAndNextStyleItem.allCases

        // when + then
        #expect(items == [.showTimeZone])
        #expect(
            TodayAndNextStyleSetting.initial[keyPath: TodayAndNextStyleItem.showTimeZone.settingKeyPath] == true
        )
    }

    @Test("설정이 가진 토글을 빠짐없이 항목으로 낸다")
    func allCases_coversEveryToggleOfSetting() {
        // given
        let toggles = Mirror(reflecting: TodayAndNextStyleSetting.initial)
            .children.filter { $0.value is Bool }

        // when + then
        #expect(TodayAndNextStyleItem.allCases.count == toggles.count)
    }
}
