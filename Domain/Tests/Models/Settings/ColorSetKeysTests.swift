//
//  ColorSetKeysTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct ColorSetKeysTests {

    @Test("시스템·기본 테마 키는 옛 저장 문자열을 그대로 쓴다")
    func rawValue_keepsLegacyStringsForSystemKeys() {
        // given + when
        let keys: [ColorSetKeys] = [.systemTheme, .defaultLight, .defaultDark]

        // then
        #expect(keys.map { $0.rawValue } == ["systemTheme", "defaultLight", "defaultDark"])
    }

    @Test("기본 제공 테마 키는 접두사를 달고 저장된다")
    func rawValue_prefixesAppThemeKeys() {
        // given + when
        let raw = ColorSetKeys.appTheme(.tomato).rawValue

        // then
        #expect(raw == "appTheme:tomato")
    }

    @Test("옛 저장 문자열은 원래 키로 복원된다")
    func init_restoresLegacyStrings() {
        // given
        let raws = ["systemTheme", "defaultLight", "defaultDark"]

        // when
        let keys = raws.map { ColorSetKeys(rawValue: $0) }

        // then
        #expect(keys == [.systemTheme, .defaultLight, .defaultDark])
    }

    @Test(
        "모르는 저장 문자열은 복원하지 않는다",
        arguments: ["appTheme:unknown", "appTheme:", "garbage", "tomato", "custom:tomato", ""]
    )
    func init_returnsNilForUnknownStrings(_ raw: String) {
        // given + when
        let key = ColorSetKeys(rawValue: raw)

        // then
        #expect(key == nil)
    }

    @Test("기본 제공 테마 키는 전부 저장 문자열을 왕복한다")
    func init_roundTripsEveryAppThemeKey() {
        // given
        let appThemeKeys = AppThemeColorSetKey.allCases
        #expect(appThemeKeys.isEmpty == false)

        // when + then
        appThemeKeys.forEach { key in
            let raw = ColorSetKeys.appTheme(key).rawValue
            #expect(raw == "appTheme:\(key.rawValue)")
            #expect(ColorSetKeys(rawValue: raw) == .appTheme(key))
        }
    }
}
