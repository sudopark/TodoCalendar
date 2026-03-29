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
    func scheduleTask()

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

    func scheduleTask() {

        let request = BGAppRefreshTaskRequest(identifier: taskId)
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.log(.backgroundSync, level: .debug, "submit task")
        } catch {
            logger.log(.backgroundSync, level: .error, "fail to sumit new background refresh task: \(error.localizedDescription)")
        }
    }

    private func handleBackgroundSync(_ task: BGAppRefreshTask) {

        logger.log(.backgroundSync, level: .debug, "background task start - will sync task")

        guard self.usecaseFactory?.eventSyncUsecase != nil
        else {
            logger.log(.backgroundSync, level: .error, "syncUsecase not prepared")
            self.scheduleTask()
            task.setTaskCompleted(success: true)
            return
        }

        task.expirationHandler = { [weak self] in
            logger.log(.backgroundSync, level: .warning, "sync job expired")
            self?.scheduleTask()
            self?.usecaseFactory?.eventSyncUsecase.cancelSync()
        }

        self.usecaseFactory?.eventSyncUsecase.sync { [weak self, weak task] in
            logger.log(.backgroundSync, level: .debug, "sync job end, and will refresh widgets")

            WidgetCenter.shared.reloadAllTimelines()

            self?.scheduleTask()
            task?.setTaskCompleted(success: true)
        }
    }
}
