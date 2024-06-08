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
        let factory = WidgetUsecaseFactory(base: .init())
        let usecase = factory.makeTodoToggleUsecase()
        let result = try await usecase.toggleTodo(todoId, eventtime)
        if result != nil {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
