//
//  EventCountdownActivityViewModelTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import UIKit

@testable import TodoCalendarAppWidget


struct EventCountdownActivityViewModelTests {

    private func makeViewModel(
        target: LiveActivityEventTarget,
        colorHex: String,
        placeName: String? = nil,
        memo: String? = nil
    ) -> EventCountdownActivityViewModel {
        let attributes = EventCountdownActivityAttributes(target: target)
        let state = EventCountdownActivityAttributes.State(
            eventName: "Test Event",
            eventTimeText: "10:00 AM",
            tagColorHex: colorHex,
            eventDate: Date(),
            startDate: Date(),
            placeName: placeName,
            memo: memo
        )
        return EventCountdownActivityViewModel(attributes, state)
    }

    @Test("invalid", arguments: ["not-a-color", "2FB457"])
    func viewModel_whenTagColorHexIsInvalid_fallsBackToGray(invalidHex: String) {
        // given
        let viewModel = makeViewModel(target: .todo(id: "1"), colorHex: invalidHex)

        // when + then
        #expect(viewModel.tagColor == UIColor.gray.asColor)
    }

    @Test("todoId when todo target", arguments: ["t1", "t123"])
    func viewModel_whenTodoTarget_exposesTodoId(_ todoId: String) {
        // given
        let viewModel = makeViewModel(target: .todo(id: todoId), colorHex: "#EEEEEE")

        // when + then
        #expect(viewModel.todoId == todoId)
    }

    @Test(
        "todoId when non-todo target",
        arguments: [
            LiveActivityEventTarget.schedule(id: "s1", turnKey: "1755400800..<1755404400"),
            LiveActivityEventTarget.holiday(uuid: "h1", dateString: "2026-08-17"),
            LiveActivityEventTarget.googleCalendar(accountId: "a1", calendarId: "c1", eventId: "e1"),
            LiveActivityEventTarget.appleCalendar(calendarId: "c1", eventId: "e1")
        ]
    )
    func viewModel_whenNotTodoTarget_hasNoTodoId(_ target: LiveActivityEventTarget) {
        // given
        let viewModel = makeViewModel(target: target, colorHex: "#EEEEEE")

        // when + then
        #expect(viewModel.todoId == nil)
    }

    @Test
    func viewModel_passesEventFieldsFromState() {
        // given
        let eventDate = Date(timeIntervalSince1970: 1755400800)
        let attributes = EventCountdownActivityAttributes(target: .todo(id: "t1"))
        let state = EventCountdownActivityAttributes.State(
            eventName: "팀 회의 준비",
            eventTimeText: "오후 3:00",
            tagColorHex: "#2FB457",
            eventDate: eventDate,
            startDate: eventDate.addingTimeInterval(-3600)
        )

        // when
        let viewModel = EventCountdownActivityViewModel(attributes, state)

        // then
        #expect(viewModel.eventName == "팀 회의 준비")
        #expect(viewModel.eventTimeText == "오후 3:00")
        #expect(viewModel.eventDate == eventDate)
    }

    @Test
    func viewModel_whenPlaceNameExists_prefersItOverMemo() {
        // given + when
        let viewModel = makeViewModel(
            target: .todo(id: "t1"), colorHex: "#EEEEEE",
            placeName: "강남 사옥 3층", memo: "노트북 챙기기"
        )

        // then
        #expect(viewModel.subtitle == "강남 사옥 3층")
    }

    @Test("subtitle falls back to memo", arguments: [nil, "", "   "])
    func viewModel_whenPlaceNameIsAbsent_fallsBackToMemo(placeName: String?) {
        // given + when
        let viewModel = makeViewModel(
            target: .todo(id: "t1"), colorHex: "#EEEEEE",
            placeName: placeName, memo: "노트북 챙기기"
        )

        // then
        #expect(viewModel.subtitle == "노트북 챙기기")
    }

    @Test
    func viewModel_whenNeitherPlaceNorMemoExists_hasNoSubtitle() {
        // given + when
        let viewModel = makeViewModel(target: .holiday(uuid: "h1", dateString: "2026-08-17"), colorHex: "#EEEEEE")

        // then
        #expect(viewModel.subtitle == nil)
    }
}
