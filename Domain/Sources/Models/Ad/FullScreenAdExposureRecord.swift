//
//  FullScreenAdExposureRecord.swift
//  Domain
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct FullScreenAdExposureRecord: Equatable, Sendable {

    public enum Scope: Hashable, Sendable {
        case application
        case service(identifier: String)
    }

    public let scope: Scope
    public let lastExposeDate: Date

    public init(scope: Scope, lastExposeDate: Date) {
        self.scope = scope
        self.lastExposeDate = lastExposeDate
    }
}
