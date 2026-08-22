//
//  GuideLinkTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct GuideLinkTests {

    private var languagePath: String {
        return Locale.isCurrentKorean ? "ko" : "en"
    }

    @Test func indexPath_pointsToGuideRootWithoutLanguage() {
        // given + when
        let path = GuideLink.indexPath

        // then
        #expect(path == "https://todo-calendar.com/guide")
    }

    @Test func aiInputPath_pointsToAIInputDocumentOfCurrentLanguage() {
        // given + when
        let path = GuideLink.aiInputPath

        // then
        #expect(path == "https://todo-calendar.com/guide/\(self.languagePath)/02-ai-input")
    }
}
