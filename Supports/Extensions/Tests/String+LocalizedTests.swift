//
//  String+LocalizedTests.swift
//  ExtensionsTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
@testable import Extensions

final class StringLocalizedTests: XCTestCase {

    // 로컬라이즈 번들을 못 찾으면 key가 그대로 반환된다 — static 전환 회귀 가드
    func testLocalized_resolveKeyToTranslation() {
        // given
        let key = "common::back"

        // when
        let localized = key.localized()

        // then
        XCTAssertEqual(localized, "Back")
    }

    func testSynthesizedStrings_resolveViaModuleBundle() {
        // then
        XCTAssertEqual(R.String.commonAnd, " and")
    }
}
