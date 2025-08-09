//
//  TodoUploadDecorateRepositoryImpleTests.swift
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


final class TodoUploadDecorateRepositoryImpleTests: TodoLocalRepositoryImpleTests {
    
    private var spyEventUploadService: SpyEventUploadService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.spyEventUploadService = .init()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.spyEventUploadService = nil
    }
    
    override func makeRepository() -> any TodoEventRepository {
        let localRepository = TodoLocalRepositoryImple(
            localStorage: self.localStorage,
            environmentStorage: self.spyEnvStorage
        )
        return TodoUploadDecorateRepositoryImple(
            localRepository: localRepository,
            eventUploadService: self.spyEventUploadService
        )
    }
}

extension TodoUploadDecorateRepositoryImpleTests {
    
    func testRepository_whenMakeTodo_apepndUploadTask() async throws {
        // given
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let todo = try await repository.makeTodoEvent(params)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let first = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(first?.uuid, todo.uuid)
        XCTAssertEqual(first?.dataType, .todo)
        XCTAssertEqual(first?.isRemovingTask, false)
    }
    
    func testRepository_whenUpdateTodo_appendUploadTask() async throws {
        // given
        let old = TodoEvent(self.dummyMakeParams)!
        self.stubSaveTodo([old])
        let repository = self.makeRepository()
        
        // when
        let params = TodoEditParams(.put)
            |> \.name .~ old.name
            |> \.eventTagId .~ old.eventTagId
        let updated = try await repository.updateTodoEvent(old.uuid, params)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let first = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(first?.uuid, updated.uuid)
        XCTAssertEqual(first?.dataType, .todo)
        XCTAssertEqual(first?.isRemovingTask, false)
    }
    
    func testReposiotry_whenRemoveTodo_appendDeleteTask() async throws {
        // given
        let todo = self.makeDummyTodo(id: "some")
        let repository = try await self.makeRepositoryWithStubTodo(todo)
        
        // when
        let _ = try await repository.removeTodo(todo.uuid, onlyThisTime: false)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let first = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(first?.uuid, "some")
        XCTAssertEqual(first?.dataType, .todo)
        XCTAssertEqual(first?.isRemovingTask, true)
    }
    
    func testRepository_whenRemoveRepeatingTodoOnlyThisTime_appendUploadTask() async throws {
        // given
        let todo = self.makeDummyTodo(id: "some", time: 0, from: 0)
        let repository = try await self.makeRepositoryWithStubTodo(todo)
        
        // when
        let _ = try await repository.removeTodo(todo.uuid, onlyThisTime: true)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let first = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(first?.uuid, "some")
        XCTAssertEqual(first?.dataType, .todo)
        XCTAssertEqual(first?.isRemovingTask, false)
    }
    
    func testRepository_whenCompleteTodoWithoutNextRepeating_appendDeleteTask() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let _ = try await repository.completeTodo(origin.uuid)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let first = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(first?.uuid, "origin")
        XCTAssertEqual(first?.dataType, .todo)
        XCTAssertEqual(first?.isRemovingTask, true)
    }
    
    func testRepository_whenCompletedTodoWithNextRepeating_appendUploadTask() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let _ = try await repository.completeTodo(origin.uuid)
        
        // then
        XCTAssertEqual(self.spyEventUploadService.uploadTasks.count, 1)
        let first = self.spyEventUploadService.uploadTasks.first
        XCTAssertEqual(first?.uuid, "origin")
        XCTAssertEqual(first?.dataType, .todo)
        XCTAssertEqual(first?.isRemovingTask, false)
    }
    
    func testRepository_whenReplaceRepeatingTodoAndNextExists_appendUploadTasks() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let result = try await repository.replaceRepeatingTodo(current: origin.uuid, to: params)
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [origin.uuid, result.newTodoEvent.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.todo, .todo]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false, false]
        )
    }
    
    func testRepository_whenReplaceRepeatingtodoAndNexNotExists_appendDeleteAndUploadTask() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100, end: 200)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let params = self.dummyMakeParams
        let result = try await repository.replaceRepeatingTodo(current: origin.uuid, to: params)
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [origin.uuid, result.newTodoEvent.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.todo, .todo]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [true, false]
        )
    }
    
    func testRepository_whenSkipRepeatingTodo_appendUploadTask() async throws {
        // given
        let origin = self.makeDummyTodo(id: "origin", time: 100, from: 100, end: nil)
        self.stubSaveTodo([origin])
        let repository = self.makeRepository()
        
        // when
        let next = try await repository.skipRepeatingTodo("origin")
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [next.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.todo]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false]
        )
    }
    
    func testRepository_whenRevertDoneTodo_appendUploadTask() async throws {
        // given
        let repository = try await self.makeRepositoryWithDoneEvents()
        
        // when
        let todo = try await repository.revertDoneTodo("id:4")
        
        // then
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.uuid }, [todo.uuid]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.dataType }, [.todo]
        )
        XCTAssertEqual(
            self.spyEventUploadService.uploadTasks.map { $0.isRemovingTask }, [false]
        )
    }
}
