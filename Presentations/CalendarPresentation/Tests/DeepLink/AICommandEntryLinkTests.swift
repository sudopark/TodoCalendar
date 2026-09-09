//
//  AICommandEntryLinkTests.swift
//  CalendarPresentationTests
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import CalendarPresentation


struct AICommandEntryLinkTests {

    @Test func url_pointsToAICommandEntryOfCalendar() {
        // given + when
        let url = AICommandEntryLink.url

        // then
        #expect(url?.absoluteString == "tc.app://calendar/ai")
    }
}
