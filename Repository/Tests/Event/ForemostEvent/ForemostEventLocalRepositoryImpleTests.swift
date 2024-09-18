//
//  ForemostEventLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 6/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Repository


class ForemostEventLocalRepositoryImpleTests: BaseLocalTests, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var todoLocalStorage: TodoLocalStorageImple!
    private var scheduleLocalStorage: ScheduleEventLocalStorageImple!
    private var envStorage: FakeEnvironmentStorage!
    
    override func setUpWithError() throws {
        self.fileName = "foremost"
        try super.setUpWithError()
        self.cancelBag = .init()
        self.todoLocalStorage = .init(sqliteService: self.sqliteService)
        self.scheduleLocalStorage = .init(sqliteService: self.sqliteService)
        self.envStorage = .init()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.cancelBag = nil
        self.todoLocalStorage = nil
        self.scheduleLocalStorage = nil
        self.envStorage = nil
    }
    
    private func makeRepsitory(
        foremost: ForemostEventId? = nil
    ) async throws -> ForemostEventLocalRepositoryImple {
        
        let todos = [
            TodoEvent.dummy(0), TodoEvent.dummy(1)
        ]
        try await self.todoLocalStorage.updateTodoEvents(todos)
        let schedules = [
            ScheduleEvent(uuid: "sc:0", name: "sc0", time: .at(0)),
            ScheduleEvent(uuid: "sc:1", name: "sc1", time: .at(0)),
        ]
        try await self.scheduleLocalStorage.updateScheduleEvents(schedules)
        
        let storage = ForemostLocalStorageImple(
            environmentStorage: self.envStorage,
            todoStorage: self.todoLocalStorage,
            scheduleStorage: self.scheduleLocalStorage
        )
        let repository = ForemostEventLocalRepositoryImple(
            localStorage: storage
        )
        if let foremost {
            _ = try await storage.updateForemostEventId(foremost)
        } else {
            try await storage.removeForemostEvent()
        }
        return repository
    }
}


extension ForemostEventLocalRepositoryImpleTests {
    
    // todo foremost 이벤트 조회
    func testRepository_loadTodoForemostEvent() async throws {
        // given
        let repository = try await self.makeRepsitory(
            foremost: .init("id:0", true)
        )
        
        // when
        let event = try await repository.foremostEvent().values.first(where: { _ in true })
        
        // then
        XCTAssertEqual(event is TodoEvent, true)
        XCTAssertEqual(event??.eventId, "id:0")
    }
    
    // schedule foremost 이벤트 조회
    func testRepository_loadScheduleForemostEvent() async throws {
        // given
        let repository = try await self.makeRepsitory(
            foremost: .init("sc:0", false)
        )
        
        // when
        let event = try await repository.foremostEvent().values.first(where: { _ in true })
        
        // then
        XCTAssertEqual(event is ScheduleEvent, true)
        XCTAssertEqual(event??.eventId, "sc:0")
    }
    
    // foremost 이벤트 없음
    func testRepository_loadForemostEventIsNil() async throws {
        // given
        let repository = try await self.makeRepsitory()
        
        // when
        let event = try await repository.foremostEvent().values.first(where: { _ in true }) ?? nil
        
        // then
        XCTAssertNil(event)
    }
    
    func testRepository_whenForemostIdExistsButEventNotExists_isNil() async throws {
        // given
        let repository = try await self.makeRepsitory(
            foremost: .init("not_exists", true)
        )
        
        // when
        let event = try await repository.foremostEvent().values.first(where: { _ in true }) ?? nil
        
        // then
        XCTAssertNil(event)
    }
    
    // foremost 이벤트 업데이트
    func testRepository_updateForemostEvent() async throws {
        // given
        let repository = try await self.makeRepsitory()
        
        // when
        let result = try await repository.updateForemostEvent(
            .init("id:1", true)
        )
        let event = try await repository.foremostEvent().values.first(where: { _ in true })
        
        // then
        XCTAssertEqual(result.eventId, "id:1")
        XCTAssertEqual(event??.eventId, "id:1")
    }
    
    // foremost 이벤트 삭제
    func testRepository_removeForemostEvent() async throws {
        // given
        let repository = try await self.makeRepsitory(
            foremost: .init("id:0", true)
        )
        
        // when
        try await repository.removeForemostEvent()
        let event = try await repository.foremostEvent().values.first(where: { _ in true }) ?? nil
        
        // then
        XCTAssertNil(event)
    }
}
