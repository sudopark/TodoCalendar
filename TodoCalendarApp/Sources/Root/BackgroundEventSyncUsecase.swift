//
//  BackgroundEventSyncUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 12/6/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
@preconcurrency import BackgroundTasks
@preconcurrency import UIKit
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
    private let refreshTaskId = "com.sudo.park.TodoCalendarApp.bgSync"

    init() {}
}


// MARK: - register & schedule

extension BackgroundEventSyncUsecaseImple {

    func change(factory: any UsecaseFactory) {
        self.usecaseFactory = factory
    }

    func registerTask() {

        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskId, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask
            else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleBackgroundSync(refreshTask)
        }

    }

    func scheduleTask() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date().addingTimeInterval(15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.log(.backgroundSync, level: .debug, "submit refresh task")
        } catch {
            logger.log(.backgroundSync, level: .error, "fail to submit refresh task: \(error.localizedDescription)")
        }
    }
}


// MARK: - handle sync

extension BackgroundEventSyncUsecaseImple {

    private func handleBackgroundSync(_ task: BGTask) {

        logger.log(.backgroundSync, level: .debug, "background task start - \(type(of: task))")

        let bgTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)

        let syncUsecase = self.usecaseFactory?.eventSyncUsecase

        task.expirationHandler = { [weak self] in
            logger.log(.backgroundSync, level: .warning, "sync job expired")
            self?.scheduleTask()
            syncUsecase?.cancelSync()
            UIApplication.shared.endBackgroundTask(bgTaskId)
        }

        self.runSync { [weak self, weak task] in
            self?.scheduleTask()
            task?.setTaskCompleted(success: true)
            UIApplication.shared.endBackgroundTask(bgTaskId)
        }
    }

    private func runSync(completion: (@Sendable() -> Void)? = nil) {

        let syncUsecase = self.usecaseFactory?.eventSyncUsecase

        syncUsecase?.sync { [weak self] in
            logger.log(.backgroundSync, level: .debug, "sync job end, and will refresh widgets")

            WidgetCenter.shared.reloadAllTimelines()

            completion?()
        }
    }
}
