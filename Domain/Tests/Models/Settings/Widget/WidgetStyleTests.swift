//
//  WidgetStyleTests.swift
//  DomainTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation

@testable import Domain


struct WidgetStyleTests {

    private func makeStyle(
        background: WidgetAppearanceSettings.Background?
    ) -> WidgetStyle {
        return WidgetStyle(
            id: .init(variant: .todaySummarySmall, style: .default),
            name: "밤 모드",
            setting: TodayStyleSetting.initial,
            background: background
        )
    }

    @Test("배경색을 안 걸면 비어 있다 — 전역을 따른다는 뜻이다")
    func background_whenNotGiven_isNil() {
        // given + when
        let style = WidgetStyle(
            id: .init(variant: .todaySummarySmall, style: .default),
            name: nil, setting: TodayStyleSetting.initial
        )

        // then
        #expect(style.background == nil)
    }

    @Test("배경색만 달라도 같은 스타일로 보지 않는다")
    func isSame_whenBackgroundDiffers_returnsFalse() {
        // given
        let custom = self.makeStyle(background: .custom(hex: "#101820"))

        // when + then
        #expect(custom.isSame(custom) == true)
        #expect(custom.isSame(self.makeStyle(background: .custom(hex: "#ffffff"))) == false)
        #expect(custom.isSame(self.makeStyle(background: nil)) == false)
        #expect(custom.isSame(self.makeStyle(background: .system)) == false)
    }
}
