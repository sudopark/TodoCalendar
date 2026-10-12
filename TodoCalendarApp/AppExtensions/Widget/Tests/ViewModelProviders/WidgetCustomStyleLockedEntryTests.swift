//
//  WidgetCustomStyleLockedEntryTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 10/11/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import WidgetKit
import Domain
import Extensions
import WidgetScenes

@testable import TodoCalendarAppWidget


struct WidgetCustomStyleLockedEntryTests {

    @Test("위젯 꾸미기 사유로 끝난 실패 엔트리는 잠김으로 읽힌다")
    func errorModel_whenCustomizeWidgetReason_isCustomStyleLocked() {
        // given + when
        let model = WidgetErrorModel(error: PaidFeatureGateFailReason(feature: .customizeWidget, licenseDays: 7))

        // then
        #expect(model.isCustomStyleLocked == true)
    }

    @Test("위젯 꾸미기가 아닌 게이트 사유로 끝난 실패 엔트리는 잠김이 아니다")
    func errorModel_whenOtherGateReason_isNotCustomStyleLocked() {
        // given + when
        let model = WidgetErrorModel(error: PaidFeatureGateFailReason(feature: .colorTheme(.custom("my-theme")), licenseDays: 7))

        // then
        #expect(model.isCustomStyleLocked == false)
    }

    @Test("다른 에러로 끝난 실패 엔트리는 잠김이 아니다")
    func errorModel_whenOtherError_isNotCustomStyleLocked() {
        // given + when
        let model = WidgetErrorModel(error: RuntimeError("load fail"))

        // then
        #expect(model.isCustomStyleLocked == false)
    }

    @Test("잠긴 AICommand 위젯은 탭하면 잠김 안내 링크로 간다")
    func aiCommandEntry_whenLocked_linksToLicense() {
        // given + when
        let entry = AICommandShortcutWidgetEntry(date: Date(), isCustomStyleLocked: true)

        // then
        #expect(entry.widgetURL?.absoluteString == "tc.app://calendar/widgetLicense")
    }

    @Test("잠기지 않은 AICommand 위젯은 탭하면 AI 입력으로 간다")
    func aiCommandEntry_whenNotLocked_linksToAICommand() {
        // given + when
        let entry = AICommandShortcutWidgetEntry(date: Date(), isCustomStyleLocked: false)

        // then
        #expect(entry.widgetURL?.absoluteString == "tc.app://calendar/ai")
    }
}
