//
//  WidgetStyleLicenseLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class WidgetStyleLicenseLocalRepositoryImple: WidgetStyleLicenseRepository, Sendable {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private var licenseKey: String { EnvironmentKeys.widgetStyleLicense.rawValue }
}


extension WidgetStyleLicenseLocalRepositoryImple {

    public func loadLicense() -> WidgetStyleLicense? {
        let mapper: WidgetStyleLicenseMapper? = self.environmentStorage.load(self.licenseKey)
        return mapper?.license
    }

    public func updateLicense(_ license: WidgetStyleLicense) {
        self.environmentStorage.update(self.licenseKey, WidgetStyleLicenseMapper(license: license))
    }
}
