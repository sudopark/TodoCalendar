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
    
    static let title: LocalizedStringResource = "To-do completion processing"
    
    @Parameter(title: "to-do id")
    var todoId: String
    
    @Parameter(title: "is foremost event")
    var isForemost: Bool

    init() { }
    
    init(id: String, isForemost: Bool) {
        self.todoId = id
        self.isForemost = isForemost
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
            if self.isForemost {
                base.userDefaultEnvironmentStorage.update(
                    EnvironmentKeys.needCheckResetWidgetCache.rawValue,
                    true
                )
            } else if result.isToggledCurrentTodo == true {
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
        WidgetCenter.shared.reloadTimelines(ofKind: NextEventWidget.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: NextRemainEventWidget.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: EventAndMonthWidget.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: EventAndForemostWidget.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: TodayAndNextWidget.kind)
    }
}
