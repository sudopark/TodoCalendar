//
//  UserEventExistenceLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class UserEventExistenceLocalRepositoryImple: UserEventExistenceRepository, Sendable {

    private let todoLocalStorage: any TodoLocalStorage
    private let scheduleLocalStorage: any ScheduleEventLocalStorage

    public init(
        todoLocalStorage: any TodoLocalStorage,
        scheduleLocalStorage: any ScheduleEventLocalStorage
    ) {
        self.todoLocalStorage = todoLocalStorage
        self.scheduleLocalStorage = scheduleLocalStorage
    }
}

extension UserEventExistenceLocalRepositoryImple {

    public func fetchHasAnyEvent() async throws -> Bool {
        let hasTodo = try await self.todoLocalStorage.hasAnyEvent()
        guard hasTodo == false else { return true }
        return try await self.scheduleLocalStorage.hasAnyEvent()
    }
}
