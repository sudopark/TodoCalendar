//
//  ColorThemeLicense.swift
//  Domain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public struct ColorThemeLicense: Equatable, Sendable {

    public let grantedAt: Date

    public init(grantedAt: Date) {
        self.grantedAt = grantedAt
    }
}


public struct ColorThemeLicensePolicy: Equatable, Sendable {

    public let licenseDays: Int

    public init(licenseDays: Int) {
        self.licenseDays = licenseDays
    }
}
