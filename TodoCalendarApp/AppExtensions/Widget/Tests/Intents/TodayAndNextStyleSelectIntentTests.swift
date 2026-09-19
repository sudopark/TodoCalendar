//
//  TodayAndNextStyleSelectIntentTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import TodoCalendarAppWidget


// MARK: - 편집 시트 후보 목록

struct TodayAndNextStyleEntityListTests {

    private func style(
        _ style: WidgetStyleId.Style, name: String?
    ) -> WidgetStyle {
        return .init(
            id: .init(variant: .todayAndNextMedium, style: style),
            name: name,
            setting: TodayAndNextStyleSetting.initial
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
        let entities = styles.map { TodayAndNextStyleEntity(style: $0) }

        // then
        #expect(entities.map { $0.id } == ["default", "custom::c1", "custom::c2"])
        #expect(entities.map { $0.name } == ["Default", "Night", "Day"])
    }

    @Test("이름 없는 커스텀 후보는 이름 없음 문구로 뜬다")
    func styleEntity_whenCustomHasNoName_usesUntitledLabel() {
        // given
        let styles = [self.style(.custom(id: "c1"), name: nil)]

        // when
        let entities = styles.map { TodayAndNextStyleEntity(style: $0) }

        // then
        #expect(entities.map { $0.name } == ["Untitled"])
    }
}


// MARK: - 인스턴스 선택 해석

struct TodayAndNextStyleParameterTests {

    private func intent(selecting entityId: String?) -> EventListComponentSelectIntent {
        let intent = EventListComponentSelectIntent()
        intent.style = entityId.map { TodayAndNextStyleEntity(id: $0, name: "any") }
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

    /// 배포된 인스턴스의 설정값이 스타일 파라미터 추가로 흔들리면 안 된다.
    @Test("스타일을 더해도 기존 파라미터는 그대로다")
    func existingParameters_unchangedAfterStyleAdded() {
        // given
        let intent = EventListComponentSelectIntent()
        intent.eventTypes = [EventTypeEntity(id: "t1", name: "Work")]
        intent.excludeAllDayEvent = true

        // when
        intent.style = TodayAndNextStyleEntity(id: "custom::c1", name: "Night")

        // then
        #expect(intent.eventTypes?.map { $0.id } == ["t1"])
        #expect(intent.excludeAllDayEvent == true)
        #expect(intent.resolvedStyle == .custom(id: "c1"))
    }
}
