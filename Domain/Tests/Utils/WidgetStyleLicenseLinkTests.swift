//
//  WidgetStyleLicenseLinkTests.swift
//  DomainTests
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct WidgetStyleLicenseLinkTests {

    @Test func url_pointsToWidgetLicense() {
        // given + when
        let url = WidgetStyleLicenseLink.url

        // then
        #expect(url?.absoluteString == "tc.app://widget/license")
    }
}
