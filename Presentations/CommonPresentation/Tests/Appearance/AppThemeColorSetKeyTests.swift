//
//  AppThemeColorSetKeyTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 9/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit
import Domain

@testable import CommonPresentation


struct AppThemeColorSetKeyTests {

    @Test("토마토 정의가 스펙 팔레트 14개를 그대로 든다")
    func definition_tomatoMatchesSpecPalette() {
        // given + when
        let definition = AppThemeColorSetKey.tomato.definition

        // then
        #expect(definition.bg0 == UIColor(rgb: 0xF1F0EF))
        #expect(definition.bg1 == UIColor(rgb: 0xFFFFFF))
        #expect(definition.todayBackground == UIColor(rgb: 0xFEEBE7))
        #expect(definition.line == UIColor(rgb: 0xDAD9D6))
        #expect(definition.text0 == UIColor(rgb: 0x21201C))
        #expect(definition.text1 == UIColor(rgb: 0x63635E))
        #expect(definition.accent == UIColor(rgb: 0xE54D2E))
        #expect(definition.selectedDayBackground == UIColor(rgb: 0xD13415))
        #expect(definition.selectedDayText == UIColor(rgb: 0xFFFFFF))
        #expect(definition.holidayOrWeekEndWithAccent == UIColor(rgb: 0xCB1D63))
        #expect(definition.bg2 == UIColor(rgb: 0xF9F9F8))
        #expect(definition.text2 == UIColor(rgb: 0x8B8B87))
        #expect(definition.placeHolder == UIColor(rgb: 0xC4C3C0))
        #expect(definition.secondaryBtnBackground == UIColor(rgb: 0xDAD9D6))
        #expect(definition.eventTextOverride == nil)
        #expect(definition.primaryBtnTextOverride == nil)
    }

    @Test("토마토 정의가 관계로 채우는 토큰을 스펙대로 답한다")
    func definition_tomatoDerivesRelatedTokens() {
        // given + when
        let colorSet: any ColorSet = AppThemeColorSetKey.tomato.definition

        // then
        #expect(colorSet.dayBackground == UIColor(rgb: 0xF1F0EF))
        #expect(colorSet.weekDayText == UIColor(rgb: 0x21201C))
        #expect(colorSet.eventText == UIColor(rgb: 0x63635E))
        #expect(colorSet.text0_inverted == UIColor(rgb: 0xF1F0EF))
        #expect(colorSet.accentAI == UIColor(rgb: 0xBB5380))
        #expect(colorSet.aiListeningBackground == [
            UIColor(rgb: 0x9C5FB5).withAlphaComponent(0.20),
            UIColor(rgb: 0xBB5380).withAlphaComponent(0.13),
            UIColor(rgb: 0xC1573D).withAlphaComponent(0.20)
        ])
    }

    @Test("기본 제공 테마 이름은 키에서 만든 문구 키를 든다")
    func definition_nameCarriesLocalizeKeyBuiltFromRawValue() {
        // given + when
        let tomatoName = AppThemeColorSetKey.tomato.definition.name

        // then
        #expect(
            tomatoName == .default(localizeKey: "setting.appearance.calendar.colorTheme::tomato")
        )
        AppThemeColorSetKey.allCases.forEach { key in
            #expect(
                key.definition.name
                    == .default(localizeKey: "setting.appearance.calendar.colorTheme::\(key.rawValue)")
            )
        }
    }
}
