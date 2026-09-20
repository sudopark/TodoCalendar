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
        background: WidgetAppearanceSettings.Background?,
        photo: WidgetStylePhoto? = nil
    ) -> WidgetStyle {
        return WidgetStyle(
            id: .init(variant: .todaySummarySmall, style: .default),
            name: "밤 모드",
            setting: TodayStyleSetting.initial,
            background: background,
            photo: photo
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

    private func photo(_ id: String) -> WidgetStylePhoto {
        return .init(
            id: id,
            original: URL(filePath: "/tmp/\(id).original"),
            rendering: URL(filePath: "/tmp/\(id).render.jpg")
        )
    }

    @Test("사진만 달라도 같은 스타일로 보지 않는다")
    func isSame_whenOnlyPhotoDiffers_isFalse() {
        // given
        let background = WidgetAppearanceSettings.Background.custom(hex: "#101820")
        let withPhoto = self.makeStyle(background: background, photo: self.photo("p1"))

        // when + then
        #expect(
            withPhoto.isSame(
                self.makeStyle(background: background, photo: self.photo("p2"))
            ) == false
        )
        #expect(withPhoto.isSame(self.makeStyle(background: background)) == false)
    }
}


// MARK: - 스타일 좌표

struct WidgetStyleIdTests {

    @Test("스타일을 공유하는 변형으로 만든 좌표는 대표 변형으로 접힌다")
    func styleId_whenMadeFromSharingVariant_normalizedToRepresentative() {
        // given
        let variants: [WidgetVariant] = [
            .twoWeekEvents, .threeWeekEvents, .fourWeekEvents,
            .currentMonthEvents, .lastMonthEvents, .nextMonthEvents
        ]

        // when
        let ids = variants.map { WidgetStyleId(variant: $0, style: .default) }

        // then
        #expect(ids.allSatisfy { $0.variant == .oneWeekEvents })
        #expect(Set(ids).count == 1)
    }

    @Test("스타일을 공유하지 않는 변형으로 만든 좌표는 그 변형 그대로다")
    func styleId_whenMadeFromNonSharingVariant_keepsItsOwn() {
        // given
        let month = WidgetStyleId(variant: .monthSmall, style: .default)
        let today = WidgetStyleId(variant: .todaySummarySmall, style: .default)

        // when + then
        #expect(month.variant == .monthSmall)
        #expect(today.variant == .todaySummarySmall)
        #expect(month != today)
    }

    @Test("공유 변형이 달라도 커스텀 스타일 좌표는 같은 것으로 본다")
    func styleId_whenCustomFromDifferentSharingVariants_areEqual() {
        // given
        let fromTwoWeeks = WidgetStyleId(variant: .twoWeekEvents, style: .custom(id: "abc"))
        let fromLastMonth = WidgetStyleId(
            variant: .lastMonthEvents, style: .custom(id: "abc")
        )

        // when + then
        #expect(fromTwoWeeks == fromLastMonth)
    }
}
