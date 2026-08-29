//
//  EventCountdownLiveActivityIntents.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import AppIntents
import Domain
import Repository


struct EndLiveActivityIntent: LiveActivityIntent {

    static let title: LocalizedStringResource = "Live activity dismissal"

    init() { }

    func perform() async throws -> some IntentResult {
        await EventCountdownActivityEndingImple().endActivities()
        return .result()
    }
}


struct CompleteTodoAndEndLiveActivityIntent: LiveActivityIntent {

    static let title: LocalizedStringResource = "To-do completion and live activity dismissal"

    @Parameter(title: "to-do id")
    var todoId: String

    init() { }

    init(todoId: String) {
        self.todoId = todoId
    }

    func perform() async throws -> some IntentResult {
        let base = AppExtensionBase()
        let repository = TodoEventRepositoryFactory(base: base).makeRepository()
        let completion = EventCountdownTodoCompletion(
            todoRepository: repository, activityEnding: EventCountdownActivityEndingImple()
        )
        let didComplete = await completion.completeTodoAndEndActivity(self.todoId)
        guard didComplete else { return .result() }

        base.userDefaultEnvironmentStorage.update(EnvironmentKeys.needCheckResetWidgetCache.rawValue, true)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
