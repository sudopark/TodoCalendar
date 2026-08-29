//
//  AppColdLaunchHistoryLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class AppColdLaunchHistoryLocalRepositoryImple: AppColdLaunchHistoryRepository, Sendable {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private var historyKey: String { EnvironmentKeys.appColdLaunchHistory.rawValue }
}

extension AppColdLaunchHistoryLocalRepositoryImple {

    public func loadColdLaunchHistory() -> AppColdLaunchHistory {
        let mapper: AppColdLaunchHistoryMapper? = self.environmentStorage.load(self.historyKey)
        return mapper?.history ?? .init()
    }

    public func updateColdLaunchHistory(_ history: AppColdLaunchHistory) {
        self.environmentStorage.update(self.historyKey, AppColdLaunchHistoryMapper(history: history))
    }
}
