//
//  GuideTodoLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


public final class GuideTodoLocalRepositoryImple: GuideTodoRepository {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private enum Constant {
        static let key: String = "guide_todo_completed"
    }
}

extension GuideTodoLocalRepositoryImple {

    public func loadIsCompleted() -> Bool {
        return self.environmentStorage.load(Constant.key) ?? false
    }

    public func markCompleted() {
        self.environmentStorage.update(Constant.key, true)
        self.environmentStorage.synchronize()
    }
}
