//
//  EventNotificationRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 1/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Repository


class EventNotificationRepositoryImpleTests: BaseLocalTests {
    
    override func setUpWithError() throws {
        self.fileName = "notifications"
        try super.setUpWithError()
    }
    
    private func makeRepository() -> EventNotificationRepositoryImple {
        let envStorage = FakeEnvironmentStorage()
        return .init(
            sqliteService: self.sqliteService,
            environmentStorage: envStorage
        )
    }
}


// MARK: - save pending notification ids

extension EventNotificationRepositoryImpleTests {
    
    func testRepository_saveAndRemovePendingNotificationIds() async throws {
        // given
        let repository = self.makeRepository()
        let eventIds = ["ev1", "ev2", "ev3"]
        
        // when
        let allIdsBeforeSave = try await repository.removeAllSavedNotificationId(of: eventIds)
        let allEvIdsMap: [String: [String]] = [
            "ev1": ["n1-1", "n1-2"],
            "ev2": ["n2-1", "n2-2"],
            "ev3": ["n3-1", "n3-2"]
        ]
        try await repository.batchSaveNotificationId(allEvIdsMap)
        
        let removeEv12Result = try await repository.removeAllSavedNotificationId(of: ["ev1", "ev2"])
        let removeEv1Result = try await repository.removeAllSavedNotificationId(of: ["ev1"])
        let removeEv3Result = try await repository.removeAllSavedNotificationId(of: ["ev3"])
        
        // then
        XCTAssertEqual(allIdsBeforeSave, [])
        XCTAssertEqual(removeEv12Result.sorted(), ["n1-1", "n1-2", "n2-1", "n2-2"])
        XCTAssertEqual(removeEv1Result, [])
        XCTAssertEqual(removeEv3Result.sorted(), ["n3-1", "n3-2"])
    }
}
