//
//  LegalLinkTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct LegalLinkTests {

    private var languagePath: String {
        return Locale.isCurrentKorean ? "ko" : "en"
    }

    @Test func termsPath_pointsToPublishedTermsRoute() {
        // given + when
        let path = LegalLink.termsPath

        // then
        #expect(path == "https://todo-calendar.com/terms/\(self.languagePath)")
    }

    @Test func privacyPolicyPath_pointsToPublishedPrivacyRoute() {
        // given + when
        let path = LegalLink.privacyPolicyPath

        // then
        #expect(path == "https://todo-calendar.com/privacy/\(self.languagePath)")
    }
}
