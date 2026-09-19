//
//  ColorSetKeysTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Domain

@testable import CommonPresentation


struct ColorSetKeysTests {

    @Test(
        "convert maps key and system scheme to color set",
        arguments: [
            (ColorSetKeys.systemTheme, true, true),
            (ColorSetKeys.systemTheme, false, false),
            (ColorSetKeys.defaultLight, true, false),
            (ColorSetKeys.defaultLight, false, false),
            (ColorSetKeys.defaultDark, true, true),
            (ColorSetKeys.defaultDark, false, true)
        ]
    )
    func convert_mapsKeyAndSystemScheme(
        _ key: ColorSetKeys, _ isSystemDarkTheme: Bool, _ expectDarkSet: Bool
    ) {
        // given + when
        let colorSet = key.convert(isSystemDarkTheme: isSystemDarkTheme)

        // then
        #expect((colorSet is DefaultDarkColorSet) == expectDarkSet)
        #expect((colorSet is DefaultLightColorSet) == !expectDarkSet)
    }
}
