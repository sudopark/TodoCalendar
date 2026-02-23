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
import Extensions


public actor EventUploadServiceImple: EventUploadService {

    private let pendingQueueStorage: any EventUploadPendingQueueLocalStorage
    private let eventTagRemote: any EventTagRemote
    private let eventTagLocalStorage: any EventTagLocalStorage
    private let todoRemote: any TodoRemote
    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleRemote: any ScheduleEventRemote
    private let scheduleLocalStorage: any ScheduleEventLocalStorage
    private let eventDetailRemote: any EventDetailRemote
    private let eventDetailLocalStorage: any EventDetailDataLocalStorage
    private let doneTodoDetailRemote: any EventDetailRemote
    private let doneTodoDetailLocalStorage: any EventDetailDataLocalStorage
    
    public init(
        pendingQueueStorage: any EventUploadPendingQueueLocalStorage,
        eventTagRemote: any EventTagRemote,
        eventTagLocalStorage: any EventTagLocalStorage,
        todoRemote: any TodoRemote,
        todoLocalStorage: any TodoLocalStorage,
        scheduleRemote: any ScheduleEventRemote,
        scheduleLocalStorage: any ScheduleEventLocalStorage,
        eventDetailRemote: any EventDetailRemote,
        eventDetailLocalStorage: any EventDetailDataLocalStorage,
        doneTodoDetailRemote: any EventDetailRemote,
        doneTodoDetailLocalStorage: any EventDetailDataLocalStorage
    ) {
        self.pendingQueueStorage = pendingQueueStorage
        self.eventTagRemote = eventTagRemote
        self.eventTagLocalStorage = eventTagLocalStorage
        self.todoRemote = todoRemote
        self.todoLocalStorage = todoLocalStorage
        self.scheduleRemote = scheduleRemote
        self.scheduleLocalStorage = scheduleLocalStorage
        self.eventDetailRemote = eventDetailRemote
        self.eventDetailLocalStorage = eventDetailLocalStorage
        self.doneTodoDetailRemote = doneTodoDetailRemote
        self.doneTodoDetailLocalStorage = doneTodoDetailLocalStorage
    }
    
    private let isUploadingFlag = EventUploadingFlag()
    private func update(isUploading: Bool) {
        self.isUploadingFlag.updateIsUploading(isUploading)
    }
    private var uploadingTask: Task<Void, any Error>?
}


extension EventUploadServiceImple {
    
    public func append(_ tasks: [EventUploadingTask]) async throws {
        try await self.pendingQueueStorage.pushTasks(tasks)
        try await self.resume()
    }
    
    public func resume() async throws {
        guard !self.isUploadingFlag.value else { return }
        self.update(isUploading: true)
        logger.log(level: .debug, "resume uploading task")
                
        self.uploadingTask = Task { [weak self] in
            
            while !Task.isCancelled, let task = try await self?.pendingQueueStorage.popTask() {
                do {
                    logger.log(level: .debug, "will upload task: \(task)")
                    try await self?.uploadTask(task)
                } catch {
                    await self?.reScheduleUploadFailedTask(task)
                    logger.log(level: .error, "upload event fail, reschedule task: \(task)")
                }
            }
            
            await self?.update(isUploading: false)
            logger.log(level: .debug, "uploading tasks end")
        }
    }
    
    public func pause() async {
        guard self.isUploadingFlag.value else { return }
        logger.log(level: .debug, "pause uploading task")
        self.uploadingTask?.cancel()
        self.update(isUploading: false)
    }
    
    private func reScheduleUploadFailedTask(_ task: EventUploadingTask) async {
        let reScheduleTask = task
            |> \.timestamp .~ Date().timeIntervalSince1970
            |> \.uploadFailCount +~ 1
        try? await self.pendingQueueStorage.pushTask(reScheduleTask)
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
            
        case .eventDetail where task.isRemovingTask:
            try? await self.eventDetailRemote.removeDetail(task.uuid)
            
        case .eventDetail:
            try await self.uploadEventDetail(task.uuid)
            
        case .doneTodo where task.isRemovingTask:
            try await self.todoRemote.removeDoneTodo(task.uuid)
            
        case .doneTodo:
            try await self.uploadDoneTodo(task.uuid)
            
        case .doneTodoDetail where task.isRemovingTask == false:
            try await self.uploadDoneTodoEventDetail(task.uuid)
            
        default: break
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
    
    private func uploadEventDetail(_ eventId: String) async throws {
        guard let detail = try await self.eventDetailLocalStorage.loadDetail(eventId)
        else { return }
        
        _ = try await self.eventDetailRemote.saveDetail(detail)
    }
    
    private func uploadDoneTodo(_ eventId: String) async throws {
        let done = try await self.todoLocalStorage.loadDoneTodoEvent(doneEventId: eventId)
        _ = try await self.todoRemote.updateDoneTodo(done)
    }
    
    private func uploadDoneTodoEventDetail(_ eventId: String) async throws {
        guard let detail = try await self.doneTodoDetailLocalStorage.loadDetail(eventId)
        else { return }
        
        _ = try await self.doneTodoDetailRemote.saveDetail(detail)
    }
}


extension EventUploadServiceImple {
    
    public var isUploading: EventUploadingFlag {
        get async {
            return self.isUploadingFlag
        }
    }
}
