//
//  ColorThemeAdOutcome.swift
//  Domain
//
//  Created by sudo.park on 10/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public enum ColorThemeAdOutcome: Sendable, Equatable {
    case grantLicenseAndProceed
    case proceedWithoutLicense
    case stop
}
