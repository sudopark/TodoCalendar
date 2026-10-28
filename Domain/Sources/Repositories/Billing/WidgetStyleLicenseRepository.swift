//
//  WidgetStyleLicenseRepository.swift
//  Domain
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol WidgetStyleLicenseRepository: Sendable {

    func loadLicense() -> WidgetStyleLicense?
    func updateLicense(_ license: WidgetStyleLicense)
}
