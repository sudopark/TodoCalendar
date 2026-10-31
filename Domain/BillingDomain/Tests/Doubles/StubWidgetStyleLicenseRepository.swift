//
//  StubWidgetStyleLicenseRepository.swift
//  BillingDomainTests
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
@testable import BillingDomain
@testable import BillingDomainInterface



final class StubWidgetStyleLicenseRepository: WidgetStyleLicenseRepository, @unchecked Sendable {

    private var license: WidgetStyleLicense?

    private(set) var didUpdatedLicense: WidgetStyleLicense?

    init(license: WidgetStyleLicense? = nil) {
        self.license = license
    }

    func loadLicense() -> WidgetStyleLicense? {
        return self.license
    }

    func updateLicense(_ license: WidgetStyleLicense) {
        self.didUpdatedLicense = license
        self.license = license
    }
}
