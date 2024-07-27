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

    init() { }
    
    init(id: String) {
        self.todoId = id
    }
    
    func perform() async throws -> some IntentResult {
        let base = AppExtensionBase()
        let factory = WidgetUsecaseFactory(base: base)
        let repository = factory.makeTodoToggleRepository()
        do {
            guard let result = try await repository.toggleTodo(todoId)
            else {
                self.reloadOnlyTodoTogglableWidgets()
                return .result()
            }
            if result.isToggledCurrentTodo == true {
                base.userDefaultEnvironmentStorage.update(
                    EnvironmentKeys.needCheckResetCurrentTodo.rawValue,
                    true
                )
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.reloadOnlyTodoTogglableWidgets()
        }
        return .result()
    }
    
    private func reloadOnlyTodoTogglableWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: EventListWidget.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: ForemostEventWidget.kind)
    }
}
