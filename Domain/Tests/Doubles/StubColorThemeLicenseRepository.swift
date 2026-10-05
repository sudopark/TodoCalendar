//
//  StubColorThemeLicenseRepository.swift
//  DomainTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation

@testable import Domain


final class StubColorThemeLicenseRepository: ColorThemeLicenseRepository, @unchecked Sendable {

    private var license: ColorThemeLicense?

    private(set) var didUpdatedLicense: ColorThemeLicense?

    init(license: ColorThemeLicense? = nil) {
        self.license = license
    }

    func loadLicense() -> ColorThemeLicense? {
        return self.license
    }

    func updateLicense(_ license: ColorThemeLicense) {
        self.didUpdatedLicense = license
        self.license = license
    }
}
