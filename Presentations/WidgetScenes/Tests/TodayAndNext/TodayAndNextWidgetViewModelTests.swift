//
//  TodayAndNextWidgetViewModelTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Prelude
import Optics
import Domain

@testable import WidgetScenes


struct TodayAndNextWidgetViewModelTests {

    private func makeModel(
        turningOff items: TodayAndNextStyleItem...
    ) -> TodayAndNextWidgetViewModel {
        let style = items.reduce(into: TodayAndNextStyleSetting.initial) { acc, item in
            acc[keyPath: item.settingKeyPath] = false
        }
        return TodayAndNextWidgetViewModel.sample()
            |> \.look .~ .init(
                globalSetting: .init(),
                appliedStyle: .init(
                    id: .init(variant: .todayAndNextMedium, style: .default),
                    name: nil, setting: style
                )
            )
    }
}


extension TodayAndNextWidgetViewModelTests {

    @Test("스타일이 없으면 표시 설정은 초기값이다")
    func style_defaultsToInitial() {
        // given
        let model = TodayAndNextWidgetViewModel.sample()

        // when + then
        #expect(model.style == TodayAndNextStyleSetting.initial)
        #expect(model.showsTimeZone == true)
    }

    @Test("초기 스타일은 타임존을 그린다")
    func initialStyle_showsEveryItem() {
        // given
        let model = self.makeModel()

        // when + then
        #expect(model.showsTimeZone == true)
    }

    @Test("타임존을 끄면 그리지 않는다")
    func whenShowTimeZoneOff_hidesTimeZone() {
        // given
        let model = self.makeModel(turningOff: .showTimeZone)

        // when + then
        #expect(model.showsTimeZone == false)
    }

    @Test("다른 변형의 payload 가 섞여 들어와도 초기값으로 떨어진다")
    func style_whenOtherPayloadApplied_isInitial() {
        // given
        let model = TodayAndNextWidgetViewModel.sample()
            |> \.look .~ .init(
                globalSetting: .init(),
                appliedStyle: .init(
                    id: .init(variant: .todayAndNextMedium, style: .default),
                    name: nil, setting: TodayStyleSetting.initial
                )
            )

        // when + then
        #expect(model.showsTimeZone == true)
    }
}
