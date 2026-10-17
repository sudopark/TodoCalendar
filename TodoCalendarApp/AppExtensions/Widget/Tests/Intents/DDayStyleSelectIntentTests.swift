//
//  DDayStyleSelectIntentTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 9/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import TodoCalendarAppWidget


// MARK: - 편집 시트 후보 목록

struct DDayStyleEntityListTests {

    private func style(
        _ style: WidgetStyleId.Style, name: String?
    ) -> WidgetStyle {
        return .init(
            id: .init(variant: .ddaySmall, style: style),
            name: name,
            setting: DDayStyleSetting.initial
        )
    }

    @Test("저장 목록 순서 그대로 후보가 서고 기본 스타일이 맨 앞이다")
    func styleEntities_keepListOrderWithDefaultFirst() {
        // given
        let styles = [
            self.style(.default, name: nil),
            self.style(.custom(id: "c1"), name: "Night"),
            self.style(.custom(id: "c2"), name: "Day")
        ]

        // when
        let entities = styles.map { DDayStyleEntity(style: $0) }

        // then
        #expect(entities.map { $0.id } == ["default", "custom::c1", "custom::c2"])
        #expect(entities.map { $0.name } == ["Default", "Night", "Day"])
    }

    @Test("중형 변형으로 저장된 스타일도 같은 좌표라 후보에 선다")
    func styleEntities_mediumVariantFoldsToSameCoordinate() {
        // given
        let medium = WidgetStyle(
            id: .init(variant: .ddayMedium, style: .custom(id: "c1")),
            name: "Night", setting: DDayStyleSetting.initial
        )

        // when
        let entity = DDayStyleEntity(style: medium)

        // then
        #expect(entity.id == "custom::c1")
    }
}


// MARK: - 인스턴스 선택 해석

struct DDayWidgetConfigurationIntentStyleTests {

    private func intent(selecting entityId: String?) -> DDayWidgetConfigurationIntent {
        let intent = DDayWidgetConfigurationIntent()
        intent.style = entityId.map { DDayStyleEntity(id: $0, name: "any") }
        return intent
    }

    @Test("고른 스타일이 없으면 기본 스타일로 읽는다")
    func resolvedStyle_whenStyleUnselected_isDefault() {
        // given
        let intent = self.intent(selecting: nil)

        // when + then
        #expect(intent.resolvedStyle == .default)
    }

    @Test("커스텀 스타일을 골랐으면 그 좌표로 읽는다")
    func resolvedStyle_mapsCustomEntityId() {
        // given
        let intent = self.intent(selecting: "custom::c1")

        // when + then
        #expect(intent.resolvedStyle == .custom(id: "c1"))
    }

    @Test("해석할 수 없는 선택값은 기본 스타일로 읽는다")
    func resolvedStyle_whenMalformedEntityId_isDefault() {
        // given
        let intent = self.intent(selecting: "broken")

        // when + then
        #expect(intent.resolvedStyle == .default)
    }
}
