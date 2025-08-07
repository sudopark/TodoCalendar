//
//  EventUploadService.swift
//  Repository
//
//  Created by sudo.park on 7/23/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


public actor EventUploadServiceImple: EventUploadService {

    private let pendingQueueStorage: any EventUploadPendingQueueLocalStorage
    private let eventTagRemote: any EventTagRemote
    private let eventTagLocalStorage: any EventTagLocalStorage
    private let todoRemote: any TodoRemote
    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleRemote: any ScheduleEventRemote
    private let scheduleLocalStorage: any ScheduleEventLocalStorage
    
    public init(
        pendingQueueStorage: any EventUploadPendingQueueLocalStorage,
        eventTagRemote: any EventTagRemote,
        eventTagLocalStorage: any EventTagLocalStorage,
        todoRemote: any TodoRemote,
        todoLocalStorage: any TodoLocalStorage,
        scheduleRemote: any ScheduleEventRemote,
        scheduleLocalStorage: any ScheduleEventLocalStorage
    ) {
        self.pendingQueueStorage = pendingQueueStorage
        self.eventTagRemote = eventTagRemote
        self.eventTagLocalStorage = eventTagLocalStorage
        self.todoRemote = todoRemote
        self.todoLocalStorage = todoLocalStorage
        self.scheduleRemote = scheduleRemote
        self.scheduleLocalStorage = scheduleLocalStorage
    }
    
    private let isUploadingFlag = EventUploadingFlag()
    private func update(isUploading: Bool) {
        // TODO: log..
        self.isUploadingFlag.updateIsUploading(isUploading)
    }
    private var uploadingTask: Task<Void, any Error>?
    private var uploadingFailTasks: [EventUploadingTask] = []
}


extension EventUploadServiceImple {
    
    public func append(_ task: EventUploadingTask) async throws {
        self.uploadingFailTasks = self.uploadingFailTasks.filter { $0.uuid != task.uuid }
        try await self.pendingQueueStorage.pushTask(task)
        try await self.resume()
    }
    
    public func resume() async throws {
        guard !self.isUploadingFlag.value else { return }
        self.update(isUploading: true)
        
        try await self.rescheduleUploadFailedJobs()
        
        self.uploadingTask = Task { [weak self] in
            
            while !Task.isCancelled, let task = try await self?.pendingQueueStorage.popTask() {
                do {
                    try await self?.uploadTask(task)
                } catch {
                    await self?.reserveReScheduleUploadFailedTask(task)
                }
            }
            
            await self?.update(isUploading: false)
        }
    }
    
    public func pause() async {
        guard self.isUploadingFlag.value else { return }
        self.uploadingTask?.cancel()
        self.update(isUploading: false)
    }
    
    public func rescheduleUploadFailedJobs() async throws {
        guard !self.uploadingFailTasks.isEmpty else { return }
        try await self.pendingQueueStorage.pushFailedTask(self.uploadingFailTasks)
        self.uploadingFailTasks = []
    }
    
    private func reserveReScheduleUploadFailedTask(_ task: EventUploadingTask) async {
        let reScheduleTask = task
            |> \.timestamp .~ Date().timeIntervalSince1970
            |> \.uploadFailCount +~ 1
        self.uploadingFailTasks.append(reScheduleTask)
    }
    
    private func uploadTask(_ task: EventUploadingTask) async throws {
        
        switch task.dataType {
        case .eventTag where task.isRemovingTask:
            try await self.eventTagRemote.deleteTag(task.uuid)
            
        case .eventTag:
            try await self.uploadEventTag(task.uuid)
            
        case .todo where task.isRemovingTask:
            _ = try await self.todoRemote.removeTodo(eventId: task.uuid)
            
        case .todo:
            try await self.uploadTodoEvent(task.uuid)
            
        case .schedule where task.isRemovingTask:
            try await self.scheduleRemote.removeScheduleEvent(task.uuid)
            
        case .schedule:
            try await self.uploadScheduleEvent(task.uuid)
        }
    }
    
    private func uploadEventTag(_ tagId: String) async throws {
        guard let tag = try await self.eventTagLocalStorage.loadTag(tagId),
              let colorHex = tag.colorHex
        else { return }
        
        let params = CustomEventTagEditParams(name: tag.name, colorHex: colorHex)
            |> \.skipCheckDuplicationName .~ true
        _ = try await self.eventTagRemote.editTag(tagId, params)
    }
    
    private func uploadTodoEvent(_ todoId: String) async throws {
        let todo = try await self.todoLocalStorage.loadTodoEvent(todoId)
        let params = TodoEditParams(.put)
            |> \.name .~ todo.name
            |> \.eventTagId .~ todo.eventTagId
            |> \.time .~ todo.time
            |> \.repeating .~ todo.repeating
            |> \.notificationOptions .~ todo.notificationOptions
        _ = try await self.todoRemote.updateTodoEvent(todoId, params)
    }
    
    private func uploadScheduleEvent(_ eventId: String) async throws {
        let schedule = try await self.scheduleLocalStorage.loadScheduleEvent(eventId)
        let params = SchedulePutParams()
            |> \.name .~ schedule.name
            |> \.eventTagId .~ schedule.eventTagId
            |> \.time .~ schedule.time
            |> \.repeating .~ schedule.repeating
            |> \.notificationOptions .~ schedule.notificationOptions
            |> \.showTurn .~ schedule.showTurn
            |> \.repeatingTimeToExcludes .~ Array(schedule.repeatingTimeToExcludes)
        _ = try await self.scheduleRemote.updateScheduleEvent(eventId, params)
    }
}


extension EventUploadServiceImple {
    
    public var isUploading: EventUploadingFlag {
        get async {
            return self.isUploadingFlag
        }
    }
}
