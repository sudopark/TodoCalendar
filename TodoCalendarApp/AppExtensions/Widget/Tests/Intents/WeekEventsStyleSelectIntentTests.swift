//
//  WeekEventsStyleSelectIntentTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import TodoCalendarAppWidget


// MARK: - 편집 시트 후보 목록

struct WeekEventsStyleEntityListTests {

    private func style(
        _ style: WidgetStyleId.Style,
        variant: WidgetVariant = .oneWeekEvents,
        name: String?
    ) -> WidgetStyle {
        return .init(
            id: .init(variant: variant, style: style),
            name: name,
            setting: WeekEventsStyleSetting.initial
        )
    }

    @Test("저장 목록 순서 그대로 후보가 서고 기본 스타일이 맨 앞이다")
    func styleEntities_keepListOrderWithDefaultFirst() {
        // given
        let styles = [
            self.style(.default, name: nil),
            self.style(.custom(id: "c1"), name: "Night")
        ]

        // when
        let entities = styles.map { WeekEventsStyleEntity(style: $0) }

        // then
        #expect(entities.map { $0.id } == ["default", "custom::c1"])
        #expect(entities.map { $0.name } == ["Default", "Night"])
    }

    /// 7변형이 좌표 하나를 공유하므로 어느 변형으로 만든 스타일이든 같은 후보 id 를 갖는다.
    @Test("공유 변형 어디서 만든 스타일이든 같은 후보 id 로 선다")
    func styleEntity_fromAnySharingVariant_hasSameId() {
        // given
        let fromThisWeek = self.style(.custom(id: "c1"), name: "Night")
        let fromLastMonth = self.style(
            .custom(id: "c1"), variant: .lastMonthEvents, name: "Night"
        )

        // when
        let entities = [fromThisWeek, fromLastMonth].map { WeekEventsStyleEntity(style: $0) }

        // then
        #expect(entities.map { $0.id } == ["custom::c1", "custom::c1"])
    }

    @Test("이름 없는 커스텀 후보는 이름 없음 문구로 뜬다")
    func styleEntity_whenCustomHasNoName_usesUntitledLabel() {
        // given
        let styles = [self.style(.custom(id: "c1"), name: nil)]

        // when
        let entities = styles.map { WeekEventsStyleEntity(style: $0) }

        // then
        #expect(entities.map { $0.name } == ["Untitled"])
    }
}


// MARK: - 인스턴스 선택 해석

struct WeekEventsWidgetConfigurationIntentTests {

    private func intent(selecting entityId: String?) -> WeekEventsWidgetConfigurationIntent {
        let intent = WeekEventsWidgetConfigurationIntent()
        intent.style = entityId.map { WeekEventsStyleEntity(id: $0, name: "any") }
        return intent
    }

    @Test("고른 스타일이 없으면 기본 스타일로 읽는다")
    func resolvedStyle_whenNoSelection_isDefault() {
        // given
        let intent = self.intent(selecting: nil)

        // when + then
        #expect(intent.resolvedStyle == .default)
    }

    @Test("커스텀 스타일을 골랐으면 그 좌표로 읽는다")
    func resolvedStyle_whenCustomSelected_isThatCustom() {
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
