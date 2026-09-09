//
//  AppDeepLinkTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct AppDeepLinkTests {

    @Test func scheme_isTheSchemeAppIsRegisteredWith() {
        // given + when
        let scheme = AppDeepLink.scheme

        // then
        #expect(scheme == "tc.app")
    }
}
