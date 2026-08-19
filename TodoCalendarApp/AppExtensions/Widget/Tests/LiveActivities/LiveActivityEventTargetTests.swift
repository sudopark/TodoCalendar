//
//  LiveActivityEventTargetTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import TodoCalendarAppWidget


struct LiveActivityEventTargetTests {

    @Test(
        "target",
        arguments: [
            LiveActivityEventTarget.todo(id: "t1"),
            LiveActivityEventTarget.schedule(id: "s1", turnKey: "1755400800..<1755404400"),
            LiveActivityEventTarget.holiday(uuid: "h1", dateString: "2026-08-17"),
            LiveActivityEventTarget.googleCalendar(accountId: "a1", calendarId: "c1", eventId: "e1"),
            LiveActivityEventTarget.appleCalendar(calendarId: "c1", eventId: "e1")
        ]
    )
    func target_encodesAndDecodes_forEveryCase(_ target: LiveActivityEventTarget) throws {
        // given
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // when
        let data = try encoder.encode(target)
        let restored = try decoder.decode(LiveActivityEventTarget.self, from: data)

        // then
        #expect(restored == target)
    }
}
