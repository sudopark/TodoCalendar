//
//  WidgetStyleSelectableTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain
import TestDoubles

@testable import TodoCalendarAppWidget


struct WidgetStyleSelectableTests {

    private func style(_ style: WidgetStyleId.Style) -> WidgetStyle {
        return .init(
            id: .init(variant: .monthSmall, style: style),
            name: nil,
            setting: MonthStyleSetting.initial
        )
    }

    private func gate(canCreate: Bool) -> StubWidgetStylePaidFeatureGateUsecase {
        let gate = StubWidgetStylePaidFeatureGateUsecase()
        gate.canCreateWithoutAd = canCreate
        return gate
    }

    @Test("커스텀을 새로 걸 권한이 없으면 기본 스타일만 후보로 남는다")
    func selectable_whenCreateDenied_keepsDefaultOnly() {
        // given
        let styles = [self.style(.default), self.style(.custom(id: "c1")), self.style(.custom(id: "c2"))]

        // when
        let selectable = styles.selectable(by: self.gate(canCreate: false), at: Date())

        // then
        #expect(selectable.map { $0.id.style } == [.default])
    }

    @Test("권한이 있으면 저장 목록을 순서 그대로 후보로 낸다")
    func selectable_whenCreateAllowed_keepsAllInOrder() {
        // given
        let styles = [self.style(.default), self.style(.custom(id: "c1")), self.style(.custom(id: "c2"))]

        // when
        let selectable = styles.selectable(by: self.gate(canCreate: true), at: Date())

        // then
        #expect(selectable.map { $0.id.style } == [.default, .custom(id: "c1"), .custom(id: "c2")])
    }

    @Test("커스텀만 저장돼 있고 권한이 없으면 후보가 비어 나온다")
    func selectable_whenOnlyCustomsAndCreateDenied_isEmpty() {
        // given
        let styles = [self.style(.custom(id: "c1"))]

        // when
        let selectable = styles.selectable(by: self.gate(canCreate: false), at: Date())

        // then
        #expect(selectable.isEmpty)
    }
}
