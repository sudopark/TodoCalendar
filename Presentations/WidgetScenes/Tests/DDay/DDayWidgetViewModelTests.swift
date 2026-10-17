//
//  DDayWidgetViewModelTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing

@testable import WidgetScenes


struct DDayWidgetViewModelTests {

    private func makeModel(
        eventTitle: String = "workshop",
        repeatText: String = ""
    ) -> DDayWidgetViewModel {
        return DDayWidgetViewModel(
            eventTitle: eventTitle,
            ddayText: "D-14",
            dateText: "2027.3.15",
            timeText: "7:00 AM",
            repeatText: repeatText
        )
    }
}


// MARK: - 잠금화면 inline 문구

extension DDayWidgetViewModelTests {

    @Test func lockScreenInlineText_joinsDDayAndTitle() {
        // given
        let model = self.makeModel()
        // when
        let text = model.lockScreenInlineText
        // then
        #expect(text == "D-14 · workshop")
    }

    @Test func lockScreenInlineText_whenTitleIsEmpty_returnsDDayOnly() {
        // given
        let model = self.makeModel(eventTitle: "")
        // when
        let text = model.lockScreenInlineText
        // then
        #expect(text == "D-14")
    }
}


// MARK: - 반복 여부

extension DDayWidgetViewModelTests {

    @Test func isRepeating_whenRepeatTextIsEmpty_returnsFalse() {
        // given
        let model = self.makeModel(repeatText: "")
        // when + then
        #expect(model.isRepeating == false)
    }

    @Test func isRepeating_whenRepeatTextExists_returnsTrue() {
        // given
        let model = self.makeModel(repeatText: "every Mon")
        // when + then
        #expect(model.isRepeating == true)
    }
}
