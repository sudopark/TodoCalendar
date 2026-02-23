//
//  EventTagUploadDecorateRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit

@testable import Repository


final class EventTagUploadDecorateRepositoryImpleTests: EventTagLocalRepositoryImpleTests {
    
    private var spyEventUploadService: SpyEventUploadService!
    private var stubRemote: StubRemoteAPI!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.spyEventUploadService = .init()
        self.stubRemote = .init(responses: self.response)
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.spyEventUploadService = nil
        self.stubRemote = nil
    }
    
    override func makeRepository() -> any EventTagRepository {
        let localRepository = EventTagLocalRepositoryImple(
            localStorage: self.localStorage,
            todoLocalStorage: self.todoLocalStorage,
            scheduleLocalStorage: self.scheduleLocalStorage,
            eventDetailLocalStorage: self.detailLocalStorage
        )
        return EventTagUploadDecorateRepositoryImple(
            localRepository: localRepository,
            eventUploadService: self.spyEventUploadService,
            remote: EventTagRemoteImple(remote: self.stubRemote)
        )
    }
}

extension EventTagUploadDecorateRepositoryImpleTests {
    
    func testRepository_whenMakeNewTag_appendUploadTask() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = CustomEventTagMakeParams(name: "some", colorHex: "hex")
        let newTag = try await repository.makeNewTag(params)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let task = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(task?.uuid, newTag.uuid)
        XCTAssertEqual(task?.dataType, .eventTag)
        XCTAssertEqual(task?.isRemovingTask, false)
    }
    
    func testRepository_whenEditTag_appendUploadTask() async throws {
        // given
        let repository = self.makeRepository()
        let params = CustomEventTagMakeParams(name: "old name", colorHex: "hex")
        let origin = try? await repository.makeNewTag(params)
        
        // when
        let editParams = CustomEventTagEditParams(name: "new name", colorHex: "new hex")
        let newOne = try? await repository.editTag(origin?.uuid ?? "", editParams)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let task = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(task?.uuid, newOne?.uuid)
        XCTAssertEqual(task?.dataType, .eventTag)
        XCTAssertEqual(task?.isRemovingTask, false)
    }
    
    func testRepository_whenRemoveTag_appendUploadTask() async throws {
        // given
        let repository = self.makeRepository()
        let params = CustomEventTagMakeParams(name: "some", colorHex: "hex")
        let origin = try await repository.makeNewTag(params)
        
        // when
        try await repository.deleteTag(origin.uuid)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let task = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(task?.uuid, origin.uuid)
        XCTAssertEqual(task?.dataType, .eventTag)
        XCTAssertEqual(task?.isRemovingTask, true)
    }
    
    func testRepository_whenRemoveTagWithEvents_removeLocalAndRemote() async throws {
        // given
        try await self.stubTodoAndSchedule()
        let repository = self.makeRepository()
        
        // when
        let result = try await repository.deleteTagWithAllEvents("t1")
        
        // then
        XCTAssertEqual(self.stubRemote.didRequestedPath, "dummy_calendar_api_host/v2/tags/tag_with_events/t1")
        let params = self.stubRemote.didRequestedParams ?? [:]
        XCTAssertEqual(params["todos"] as? [String], result.todoIds)
        XCTAssertEqual(params["schedules"] as? [String], result.scheduleIds)
    }
}


private extension EventTagUploadDecorateRepositoryImpleTests {
    
    private var response: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .delete,
                endpoint: EventTagEndpoints.tagWithEvents(id: "t1"),
                resultJsonString: .success("{ \"status\": \"ok\"}")
            ),
        ]
    }
}
