//
//  EventCountdownActivityActions.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import ActivityKit
import Domain


protocol EventCountdownActivityEnding: Sendable {
    func endActivities() async
}

struct EventCountdownActivityEndingImple: EventCountdownActivityEnding {

    init() { }

    /// 이미 끝난 액티비티에 `end`를 다시 부르는 건 no-op이라 `activityState` 필터를 두지 않는다
    func endActivities() async {
        for activity in Activity<EventCountdownActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

struct EventCountdownTodoCompletion: Sendable {

    private let todoRepository: any TodoEventRepository
    private let activityEnding: any EventCountdownActivityEnding

    init(
        todoRepository: any TodoEventRepository,
        activityEnding: any EventCountdownActivityEnding
    ) {
        self.todoRepository = todoRepository
        self.activityEnding = activityEnding
    }

    func completeTodoAndEndActivity(_ todoId: String) async -> Bool {
        do {
            _ = try await self.todoRepository.completeTodo(todoId)
        } catch {
            return false
        }
        await self.activityEnding.endActivities()
        return true
    }
}
