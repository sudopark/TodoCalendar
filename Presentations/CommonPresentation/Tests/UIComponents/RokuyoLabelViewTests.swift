//
//  RokuyoLabelViewTests.swift
//  CommonPresentationTests
//
//  Created by sudo.park on 11/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit
import CalendarDomainInterface

@testable import CommonPresentation


struct RokuyoLabelViewTests {

    @Test func dotColor_isVisibleAndDistinctForEveryRokuyo() {
        // given
        let rokuyos = Rokuyo.allCases

        // when
        let colors = rokuyos.map { $0.dotColor }

        // then
        #expect(colors.allSatisfy { $0.cgColor.alpha == 1 })
        #expect(Set(colors).count == rokuyos.count)
    }

    @Test func localizedName_isTranslatedForEveryRokuyo() {
        // given
        let rokuyos = Rokuyo.allCases

        // when
        let names = rokuyos.map { $0.localizedName }

        // then
        #expect(names.allSatisfy { !$0.hasPrefix("rokuyo::") })
        #expect(Set(names).count == rokuyos.count)
    }
}
