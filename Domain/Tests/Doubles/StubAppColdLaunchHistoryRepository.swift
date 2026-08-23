//
//  StubAppColdLaunchHistoryRepository.swift
//  DomainTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import Domain


final class StubAppColdLaunchHistoryRepository: AppColdLaunchHistoryRepository, @unchecked Sendable {

    private var history: AppColdLaunchHistory

    init(history: AppColdLaunchHistory = .init()) {
        self.history = history
    }

    func loadColdLaunchHistory() -> AppColdLaunchHistory {
        return self.history
    }

    func updateColdLaunchHistory(_ history: AppColdLaunchHistory) {
        self.history = history
    }
}
