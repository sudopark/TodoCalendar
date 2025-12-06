//
//  BackgroundEventSyncUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 12/6/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
@preconcurrency import BackgroundTasks
import Domain
import Scenes
import Extensions


protocol BackgroundEventSyncUsecase: Sendable {
    
    func change(factory: any UsecaseFactory)
    
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
    
    private func handleBackgroundSync(_ task: BGAppRefreshTask) {
        
        self.debugLog("will run sync")
        self.scheduleNextTask()
        
        guard let syncUsecase = self.usecaseFactory?.eventSyncUsecase
        else {
            self.debugLog("syncUsecase not prepared")
            task.setTaskCompleted(success: true)
            return
        }
        
        task.expirationHandler = { [weak syncUsecase] in
            self.debugLog("sync job expired")
            syncUsecase?.cancelSync()
        }
        
        syncUsecase.sync { [weak task] in
            self.debugLog("sync job end")
            task?.setTaskCompleted(success: true)
        }
    }
    
    private func scheduleNextTask() {
        
        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date().addingTimeInterval(3600)
        
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
        do {
            try BGTaskScheduler.shared.submit(request)
            self.debugLog("schedule next task")
        } catch {
            logger.log(level: .error, "TodoCalendar: fail to sumit new background refresh task: \(error.localizedDescription)")
        }
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("TodoCalendar-background sync: \(message)")
        #endif
    }
}
