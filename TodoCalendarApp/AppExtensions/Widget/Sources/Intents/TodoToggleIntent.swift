//
//  TodoToggleIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import AppIntents
import Prelude
import Optics
import Domain
import Repository


struct TodoToggleIntent: AppIntent {
    
    static var title: LocalizedStringResource = "To-do completion processing"
    
    @Parameter(title: "to-do id")
    var todoId: String

    var eventtime: EventTime?
    
    init() { }
    
    init(id: String, _ eventTime: EventTime?) {
        self.todoId = id
        self.eventtime = eventTime
    }
    
    func perform() async throws -> some IntentResult {
        let base = WidgetBaseDependency()
        let factory = WidgetUsecaseFactory(base: base)
        let usecase = factory.makeTodoToggleUsecase()
        do {
            let result = try await usecase.toggleTodo(todoId, eventtime)
            guard result != nil else { return .result()  }
            if self.eventtime == nil {
                base.userDefaultEnvironmentStorage.update(
                    EnvironmentKeys.needCheckResetCurrentTodo.rawValue,
                    true
                )
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            WidgetCenter.shared.reloadTimelines(ofKind: "EventList")
        }
        return .result()
    }
}
