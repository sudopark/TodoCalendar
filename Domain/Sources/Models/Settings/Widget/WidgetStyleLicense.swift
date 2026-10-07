//
//  WidgetStyleLicense.swift
//  Domain
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct WidgetStyleLicense: Equatable, Sendable {

    public let grantedAt: Date

    public init(grantedAt: Date) {
        self.grantedAt = grantedAt
    }
}


public struct WidgetStyleLicensePolicy: Equatable, Sendable {

    public var isEnabled: Bool?
    public var licenseDays: Int?

    public init(isEnabled: Bool? = nil, licenseDays: Int? = nil) {
        self.isEnabled = isEnabled
        self.licenseDays = licenseDays
    }
}
