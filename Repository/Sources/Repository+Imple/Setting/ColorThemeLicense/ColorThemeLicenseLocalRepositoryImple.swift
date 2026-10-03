//
//  ColorThemeLicenseLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class ColorThemeLicenseLocalRepositoryImple: ColorThemeLicenseRepository, Sendable {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private var licenseKey: String { EnvironmentKeys.colorThemeLicense.rawValue }
}


extension ColorThemeLicenseLocalRepositoryImple {

    public func loadLicense() -> ColorThemeLicense? {
        let mapper: ColorThemeLicenseMapper? = self.environmentStorage.load(self.licenseKey)
        return mapper?.license
    }

    public func updateLicense(_ license: ColorThemeLicense) {
        self.environmentStorage.update(self.licenseKey, ColorThemeLicenseMapper(license: license))
    }
}
