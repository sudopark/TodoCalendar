//
//  ColorSetKeys+PaidFeature.swift
//  Domain
//
//  Created by sudo.park on 10/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


extension ColorSetKeys {

    public var paidFeature: PaidFeature {
        guard case .custom = self else { return .colorTheme(isCustom: false) }
        return .colorTheme(isCustom: true)
    }
}
