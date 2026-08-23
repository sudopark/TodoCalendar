//
//  AppColdLaunchHistoryRepository.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol AppColdLaunchHistoryRepository: Sendable {

    func loadColdLaunchHistory() -> AppColdLaunchHistory
    func updateColdLaunchHistory(_ history: AppColdLaunchHistory)
}
