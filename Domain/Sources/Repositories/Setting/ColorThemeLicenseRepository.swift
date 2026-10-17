//
//  ColorThemeLicenseRepository.swift
//  Domain
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


public protocol ColorThemeLicenseRepository: Sendable {

    func loadLicense() -> ColorThemeLicense?
    func updateLicense(_ license: ColorThemeLicense)
}
