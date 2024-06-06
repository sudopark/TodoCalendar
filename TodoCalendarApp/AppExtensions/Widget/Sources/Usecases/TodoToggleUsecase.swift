//
//  TodoToggleUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/6/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


// MARK: - TodoToggleUsecase

protocol TodoToggleUsecase {
    
    func toggleTodo(
        _ id: String, _ eventTime: EventTime?
    ) async throws -> TodoToggleResult?
}


// MARK: - TodoTogglingProcessStorage

protocol TodoTogglingProcessStorage {
    
    func isToggling(id: String) -> Bool
    func updateIsToggling(id: String, _ newValue: Bool)
}

extension UserDefaults: TodoTogglingProcessStorage {
    
    private func todoKey(_ id: String) -> String { "toggle_todo:\(id)" }
    
    func isToggling(id: String) -> Bool {
        return self.bool(forKey: self.todoKey(id))
    }
    
    func updateIsToggling(id: String, _ newValue: Bool) {
        self.set(newValue, forKey: self.todoKey(id))
    }
}


// MARK: - TodoToggleUsecaseImple

final class TodoToggleUsecaseImple: TodoToggleUsecase {
    
    private let processStorage: any TodoTogglingProcessStorage
    private let todoRepository: any TodoEventRepository
    
    init(
        processStorage: any TodoTogglingProcessStorage,
        todoRepository: any TodoEventRepository) {
        self.processStorage = processStorage
        self.todoRepository = todoRepository
    }
}

extension TodoToggleUsecaseImple {
    
    func toggleTodo(
        _ id: String, _ eventTime: EventTime?
    ) async throws -> TodoToggleResult? {
        guard !self.processStorage.isToggling(id: id)
        else {
            return nil
        }
        
        do {
            let result = try await self.todoRepository.toggleTodo(id, eventTime)
            self.processStorage.updateIsToggling(id: id, false)
            return result
        } catch {
            self.processStorage.updateIsToggling(id: id, false)
            throw error
        }
    }
}
