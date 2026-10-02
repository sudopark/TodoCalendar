//
//  CalendarPaperColumnLayoutTests.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Testing

@testable import CalendarScenes


struct CalendarPaperColumnLayoutTests {

    @Test(
        "size class 가 둘 다 Regular 일 때만 2단이다",
        arguments: [
            (UserInterfaceSizeClass?.some(.regular), UserInterfaceSizeClass?.some(.regular), CalendarPaperColumnLayout.twoColumns),
            (.some(.compact), .some(.regular), .singleColumn),
            (.some(.regular), .some(.compact), .singleColumn),
            (.some(.compact), .some(.compact), .singleColumn),
            (nil, .some(.regular), .singleColumn)
        ]
    )
    func columnLayout_isTwoColumns_onlyWhenBothRegular(
        _ horizontal: UserInterfaceSizeClass?,
        _ vertical: UserInterfaceSizeClass?,
        _ expected: CalendarPaperColumnLayout
    ) {
        // given
        // when
        let layout = CalendarPaperColumnLayout(horizontal: horizontal, vertical: vertical)

        // then
        #expect(layout == expected)
    }

    @Test(
        "접힌 달력은 1단에서만 접혀 보인다",
        arguments: [
            (CalendarPaperColumnLayout.singleColumn, true, true),
            (.singleColumn, false, false),
            (.twoColumns, true, false),
            (.twoColumns, false, false)
        ]
    )
    func columnLayout_showsCollapsedMonth_onlyInSingleColumn(
        _ layout: CalendarPaperColumnLayout,
        _ isCollapsed: Bool,
        _ expected: Bool
    ) {
        // given
        // when
        let shows = layout.showsCollapsedMonth(isCollapsed: isCollapsed)

        // then
        #expect(shows == expected)
    }

    @Test(
        "2단에서 선택된 날을 다시 탭할 때만 탭을 전달하지 않는다",
        arguments: [
            (CalendarPaperColumnLayout.twoColumns, true, false),
            (.twoColumns, false, true),
            (.singleColumn, true, true),
            (.singleColumn, false, true)
        ]
    )
    func columnLayout_forwardsDayTap_exceptReselectInTwoColumns(
        _ layout: CalendarPaperColumnLayout,
        _ isReselect: Bool,
        _ expected: Bool
    ) {
        // given
        // when
        let forwards = layout.forwardsDayTap(isReselect: isReselect)

        // then
        #expect(forwards == expected)
    }
}
