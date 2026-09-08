//
//  E2EFixtureTests.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import XCTest


final class E2EFixtureTests: XCTestCase {
    
    func test_holidaysJSON_replacesNameAndDatePlaceholders() throws {
        // given
        let fixture = E2EFixture()
        let day = try XCTUnwrap(
            DateComponents(calendar: .current, year: 2026, month: 9, day: 8).date
        )
        
        // when
        let json = fixture.holidaysJSON(named: "e2e-marker-42", on: day)
        
        // then
        let decoded = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
        let items = try XCTUnwrap(decoded["items"] as? [[String: Any]])
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?["summary"] as? String, "e2e-marker-42")
        XCTAssertEqual((items.first?["start"] as? [String: Any])?["date"] as? String, "2026-09-08")
    }
}
