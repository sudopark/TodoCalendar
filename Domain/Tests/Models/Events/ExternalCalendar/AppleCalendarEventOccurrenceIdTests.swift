//
//  AppleCalendarEventOccurrenceIdTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


@Suite("AppleCalendarEventOccurrenceIdTests")
struct AppleCalendarEventOccurrenceIdTests {

    @Test func occurrenceId_whenPlainId_hasNoOccurrenceDate() {
        // given
        let compositeId = "evt-1"

        // when
        let occurrenceId = AppleCalendar.EventOccurrenceId(compositeId)

        // then
        #expect(occurrenceId.originalEventId == "evt-1")
        #expect(occurrenceId.occurrenceDate == nil)
    }

    @Test func occurrenceId_whenCompositeId_splitsIdAndDate() {
        // given
        let compositeId = "evt-1#occ:1700000000"

        // when
        let occurrenceId = AppleCalendar.EventOccurrenceId(compositeId)

        // then
        #expect(occurrenceId.originalEventId == "evt-1")
        #expect(occurrenceId.occurrenceDate == Date(timeIntervalSince1970: 1700000000))
    }

    @Test func occurrenceId_whenIdContainsHash_splitsOnLastMarker() {
        // given
        let compositeId = "evt#1#occ:1700000000"

        // when
        let occurrenceId = AppleCalendar.EventOccurrenceId(compositeId)

        // then
        #expect(occurrenceId.originalEventId == "evt#1")
        #expect(occurrenceId.occurrenceDate == Date(timeIntervalSince1970: 1700000000))
    }

    @Test func occurrenceId_whenMarkerHasNonNumericSuffix_treatsWholeAsId() {
        // given
        let compositeId = "evt-1#occ:abc"

        // when
        let occurrenceId = AppleCalendar.EventOccurrenceId(compositeId)

        // then
        #expect(occurrenceId.originalEventId == "evt-1#occ:abc")
        #expect(occurrenceId.occurrenceDate == nil)
    }
}
