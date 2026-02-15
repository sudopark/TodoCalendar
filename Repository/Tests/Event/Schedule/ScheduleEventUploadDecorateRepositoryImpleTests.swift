//
//  ScheduleEventUploadDecorateRepositoryImpleTests.swift
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
import UnitTestHelpKit

@testable import Repository


final class ScheduleEventUploadDecorateRepositoryImpleTests: ScheduleEventLocalRepositoryImpleTests {
    
    private var spyEventUploadService: SpyEventUploadService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.spyEventUploadService = .init()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.spyEventUploadService = nil
    }
    
    override func makeRepository() -> any ScheduleEventRepository {
        let localRepository = ScheduleEventLocalRepositoryImple(
            localStorage: self.localStorage,
            environmentStorage: self.spyEnvStorage
        )
        return ScheduleEventUploadDecorateRepositoryImple(
            localRepository: localRepository,
            eventUploadService: self.spyEventUploadService
        )
    }
}

extension ScheduleEventUploadDecorateRepositoryImpleTests {
    
    func testRepository_whenMakeEvent_appenduploadTask() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let new = try await repository.makeScheduleEvent(params)
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [new.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.schedule]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false]
        )
    }
    
    func testRepository_whenUpdateEvent_appendUploadTask() async throws {
        // given
        let repository = self.makeRepository()
        let origin = try await repository.makeScheduleEvent(self.dummyMakeParams)
        
        // when
        let params = SchedulePutParams()
            |> \.time .~ .at(0)
        let updated = try await repository.updateScheduleEvent(origin.uuid, params)
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [updated.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.schedule]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false]
        )
    }
    
    func testRepository_whenRemoveEventWithoutNextRepeating_appendDeleteTask() async throws {
        // given
        let schedule = self.makeDummySchedule(id: "some", time: 0)
        let repository = try await self.makeRepositoryWithStubSchedule(schedule)
        
        // when
        let _ = try await repository.removeEvent(schedule.uuid, onlyThisTime: nil)
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [schedule.uuid, schedule.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.schedule, .eventDetail]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [true, true]
        )
    }
    
    func testRepository_whenRemoveEventWithNextRepeating_appendUploadTask() async throws {
        // given
        let schedule = self.makeDummySchedule(id: "some", time: 0, from: 0)
        let repository = try await self.makeRepositoryWithStubSchedule(schedule)
        
        // when
        let result = try await repository.removeEvent(schedule.uuid, onlyThisTime: .at(0))
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [result.nextRepeatingEvnet?.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.schedule]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false]
        )
    }
    
    func testRepository_whenBranchRepeaintEvent_appendUploadTasks() async throws {
        // given
        let reposiotry = self.makeRepository()
        let origin = self.dummyRepeatingOrigin
        try await self.localStorage.saveScheduleEvent(origin)
        
        // when
        let params = SchedulePutParams()
        |> \.name .~ "new"
        |> \.time .~ .at(100)
        |> \.repeating .~ pure(EventRepeating(repeatingStartTime: 100, repeatOption: EventRepeatingOptions.EveryDay()))
        let result = try await reposiotry.branchNewRepeatingEvent(
            "repeating", fromTime: 100, params
        )
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [result.reppatingEndOriginEvent.uuid, result.newRepeatingEvent.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.schedule, .schedule]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false, false]
        )
    }
    
    func testRepository_whenExcludeRepeatingEvent_appendUploadTasks() async throws {
        // given
        let repository = self.makeRepository()
        let origin = try await repository.makeScheduleEvent(self.dummyMakeParams)
        
        // when
        let time = EventTime.at(100)
        let newParams = self.dummyMakeParams
            |> \.time .~ .at(100)
            |> \.name .~ "new name"
        let result = try await repository.excludeRepeatingEvent(
            origin.uuid,
            at: time, asNew: newParams
        )
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [result.originEvent.uuid, result.newEvent.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.schedule, .schedule]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false, false]
        )
    }
}
