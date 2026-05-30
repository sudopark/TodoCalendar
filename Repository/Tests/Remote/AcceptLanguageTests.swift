//
//  AcceptLanguageTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 5/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing

@testable import Repository


struct AcceptLanguageTests {

    @Test func headerValue_singleLanguage_hasNoQuality() {
        // given + when
        let value = AcceptLanguage.headerValue(from: ["en"])
        // then
        #expect(value == "en")
    }

    @Test func headerValue_multipleLanguages_appendsDescendingQuality() {
        // given + when
        let value = AcceptLanguage.headerValue(from: ["ko-KR", "en-US"])
        // then
        #expect(value == "ko-KR,en-US;q=0.9")
    }

    @Test func headerValue_threeLanguages_decreasesQualityByIndex() {
        // given + when
        let value = AcceptLanguage.headerValue(from: ["ko-KR", "en-US", "ja-JP"])
        // then
        #expect(value == "ko-KR,en-US;q=0.9,ja-JP;q=0.8")
    }

    @Test func headerValue_empty_fallsBackToEnglish() {
        // given + when
        let value = AcceptLanguage.headerValue(from: [])
        // then
        #expect(value == "en")
    }
}
