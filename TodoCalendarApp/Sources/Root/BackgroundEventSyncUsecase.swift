//
//  BackgroundEventSyncUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 12/6/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
@preconcurrency import BackgroundTasks
import WidgetKit
import Domain
import Scenes
import Extensions


protocol BackgroundEventSyncUsecase: Sendable {
    
    func change(factory: any UsecaseFactory)
    func scheduleTask(withCancel: Bool)
    
    func registerTask()
}


final class BackgroundEventSyncUsecaseImple: BackgroundEventSyncUsecase, @unchecked Sendable {
    
    var usecaseFactory: (any UsecaseFactory)?
    private let taskId = "com.sudo.park.TodoCalendarApp.bgSync"
    
    init() {}
}


extension BackgroundEventSyncUsecaseImple {
    
    func change(factory: any UsecaseFactory) {
        self.usecaseFactory = factory
    }
    
    func registerTask() {
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask
            else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleBackgroundSync(refreshTask)
        }
    }
    
    func scheduleTask(withCancel: Bool) {
        
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date().addingTimeInterval(3600)
        
        if withCancel {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
        }
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.log(.backgroundSync, level: .debug, "submit task")
        } catch {
            logger.log(.backgroundSync, level: .error, "fail to sumit new background refresh task: \(error.localizedDescription)")
        }
    }
    
    private func handleBackgroundSync(_ task: BGAppRefreshTask) {
        
        logger.log(.backgroundSync, level: .debug, "background task start - will sync task")
        
        self.scheduleTask(withCancel: false)
        
        guard let syncUsecase = self.usecaseFactory?.eventSyncUsecase
        else {
            logger.log(.backgroundSync, level: .error, "syncUsecase not prepared")
            task.setTaskCompleted(success: true)
            return
        }
        
        task.expirationHandler = { [weak syncUsecase] in
            logger.log(.backgroundSync, level: .warning, "sync job expired")
            syncUsecase?.cancelSync()
        }
        
        syncUsecase.sync { [weak task] in
            logger.log(.backgroundSync, level: .debug, "sync job end, and will refresh widgets")
            
            WidgetCenter.shared.reloadAllTimelines()
            
            task?.setTaskCompleted(success: true)
        }
    }
}
