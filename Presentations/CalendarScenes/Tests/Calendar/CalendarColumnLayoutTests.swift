//
//  CalendarColumnLayoutTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Testing
import Scenes

@testable import CalendarScenes


struct CalendarColumnLayoutTests {

    @Test(
        "size class 가 가로·세로 둘 다 Regular 일 때만 2단이다",
        arguments: [
            (UIUserInterfaceSizeClass.regular, UIUserInterfaceSizeClass.regular, CalendarColumnLayout.twoColumns),
            (.compact, .regular, .singleColumn),
            (.regular, .compact, .singleColumn),
            (.compact, .compact, .singleColumn),
            (.unspecified, .regular, .singleColumn),
            (.regular, .unspecified, .singleColumn)
        ]
    )
    func layout_isTwoColumns_onlyWhenBothRegular(
        _ horizontal: UIUserInterfaceSizeClass,
        _ vertical: UIUserInterfaceSizeClass,
        _ expected: CalendarColumnLayout
    ) {
        // given
        // when
        let layout = CalendarColumnLayout(horizontal: horizontal, vertical: vertical)

        // then
        #expect(layout == expected)
    }
}
