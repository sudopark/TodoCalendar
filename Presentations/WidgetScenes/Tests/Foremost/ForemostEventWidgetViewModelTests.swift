//
//  ForemostEventWidgetViewModelTests.swift
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


struct ForemostEventWidgetViewModelTests {

    private func makeModel(
        turningOff items: ForemostStyleItem...
    ) -> ForemostEventWidgetViewModel {
        let style = items.reduce(into: ForemostStyleSetting.initial) { acc, item in
            acc[keyPath: item.settingKeyPath] = false
        }
        return ForemostEventWidgetViewModel.sample()
            |> \.look .~ .init(
                globalSetting: .init(),
                appliedStyle: .init(
                    id: .init(variant: .foremostSmall, style: .default),
                    name: nil, setting: style
                )
            )
    }
}


extension ForemostEventWidgetViewModelTests {

    @Test("스타일이 없으면 표시 설정은 초기값이다")
    func style_defaultsToInitial() {
        // given
        let model = ForemostEventWidgetViewModel.sample()

        // when + then
        #expect(model.style == ForemostStyleSetting.initial)
        #expect(model.showsTypeLabel == true)
    }

    @Test("초기 스타일은 종류 라벨을 그린다")
    func initialStyle_showsEveryItem() {
        // given
        let model = self.makeModel()

        // when + then
        #expect(model.showsTypeLabel == true)
    }

    @Test("종류 라벨을 꺼도 이벤트 내용은 그대로 남는다")
    func whenShowTypeLabelOff_keepsEventContent() {
        // given
        let model = self.makeModel(turningOff: .showTypeLabel)

        // when + then
        #expect(model.showsTypeLabel == false)
        #expect(model.eventModel != nil)
    }

    @Test("잠금화면 변형의 스타일이 섞여 들어와도 초기값으로 떨어진다")
    func style_whenOtherPayloadApplied_isInitial() {
        // given
        let model = ForemostEventWidgetViewModel.sample()
            |> \.look .~ .init(
                globalSetting: .init(),
                appliedStyle: .init(
                    id: .init(variant: .foremostSmall, style: .default),
                    name: nil, setting: TodayStyleSetting.initial
                )
            )

        // when + then
        #expect(model.showsTypeLabel == true)
    }
}
