//
//  ForemostStyleItemTests.swift
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


struct ForemostStyleItemTests {

    @Test("항목이 늘 그려지는 요소라 부연 설명이 붙지 않는다")
    func note_isEmptyForAllItems() {
        // given
        let items = ForemostStyleItem.allCases

        // when
        let itemsHavingNote = items.filter { $0.note != nil }

        // then
        #expect(itemsHavingNote.isEmpty == true)
    }

    @Test("종류 라벨 항목 하나를 갖고 설정의 그 값을 가리킨다")
    func settingKeyPath_pointsshowTypeLabel() {
        // given
        let items = ForemostStyleItem.allCases

        // when + then
        #expect(items == [.showTypeLabel])
        #expect(
            ForemostStyleSetting.initial[keyPath: ForemostStyleItem.showTypeLabel.settingKeyPath] == true
        )
    }

    @Test("설정이 가진 토글을 빠짐없이 항목으로 낸다")
    func allCases_coversEveryToggleOfSetting() {
        // given
        let toggles = Mirror(reflecting: ForemostStyleSetting.initial)
            .children.filter { $0.value is Bool }

        // when + then
        #expect(ForemostStyleItem.allCases.count == toggles.count)
    }
}
