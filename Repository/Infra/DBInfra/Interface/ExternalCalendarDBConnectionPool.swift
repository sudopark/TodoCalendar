//
//  ExternalCalendarDBConnectionPool.swift
//  DBInfraInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteService


public protocol ExternalCalendarDBConnectionPool: Sendable {

    func hasConnection(serviceId: String) async -> Bool
    func connection(serviceId: String) async throws -> SQLiteService
}
