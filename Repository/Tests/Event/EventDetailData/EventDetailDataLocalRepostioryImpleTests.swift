//
//  EventDetailDataLocalRepostioryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/28/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


class EventDetailDataLocalRepostioryImpleTests: BaseLocalTests {
    
    private var localStorage: EventDetailDataLocalStorageImple!
    
    override func setUpWithError() throws {
        self.fileName = "details"
        try super.setUpWithError()
        self.localStorage = .init(sqliteService: self.sqliteService)
        self.sqliteService.run { db in
            try db.createTableOrNot(EventDetailDataTable.self)
        }
    }
    
    override func tearDownWithError() throws {
        self.localStorage = nil
        try super.tearDownWithError()
    }
    
    private func makeRepository() -> EventDetailDataLocalRepostioryImple {
        return .init(localStorage: self.localStorage)
    }
}

extension EventDetailDataLocalRepostioryImpleTests {
    
    func testRepository_saveAndLoadDetail() async throws {
        // given
        let repository = self.makeRepository()
        let detail = EventDetailData("some")
            |> \.url .~ "https://wwww.some.url.addr"
            |> \.memo .~ "some memo"
            |> \.place .~ (
                .init("place_name", .init(100, 300)) |> \.addressText .~ "addr"
            )
        
        // when
        let _ = try await repository.saveDetail(detail)
        let loadedDetail = try await repository.loadDetail("some").firstValue(with: 100)
        
        // then
        XCTAssertEqual(loadedDetail?.eventId, detail.eventId)
        XCTAssertEqual(loadedDetail?.url, detail.url)
        XCTAssertEqual(loadedDetail?.memo, detail.memo)
        XCTAssertEqual(loadedDetail?.place?.placeName, detail.place?.placeName)
        XCTAssertEqual(loadedDetail?.place?.addressText, detail.place?.addressText)
        XCTAssertEqual(loadedDetail?.place?.coordinate, detail.place?.coordinate)
    }
    
    func testRepository_removeDetail() async throws {
        // given
        let repository = self.makeRepository()
        let detail = EventDetailData("dummy")
        try await self.localStorage.saveDetail(detail)
        
        // when + then
        try await repository.removeDetail(detail.eventId)
    }
}
