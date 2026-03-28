//
//  ExternalCalendarDBConnectionPool.swift
//  Domain
//
//  Created by sudo.park on 3/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol ExternalCalendarDBConnectionControl: Sendable {

    func open(serviceId: String) async throws
    func close(serviceId: String) async throws
}
