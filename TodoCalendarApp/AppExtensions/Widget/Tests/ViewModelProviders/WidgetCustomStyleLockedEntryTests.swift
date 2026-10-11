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

    @Test("잠김 에러로 끝난 실패 엔트리는 잠김으로 읽힌다")
    func errorModel_whenLockedError_isCustomStyleLocked() {
        // given + when
        let model = WidgetErrorModel(error: WidgetCustomStyleLockedError())

        // then
        #expect(model.isCustomStyleLocked == true)
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
        #expect(entry.widgetURL?.absoluteString == "tc.app://widget/license")
    }

    @Test("잠기지 않은 AICommand 위젯은 탭하면 AI 입력으로 간다")
    func aiCommandEntry_whenNotLocked_linksToAICommand() {
        // given + when
        let entry = AICommandShortcutWidgetEntry(date: Date(), isCustomStyleLocked: false)

        // then
        #expect(entry.widgetURL?.absoluteString == "tc.app://calendar/ai")
    }

    @Test("커스텀을 고른 AICommand 위젯은 만료를 따라가려 정규 갱신을 받는다")
    func aiCommandRefreshPolicy_whenCustom_refreshesRegularly() {
        // given
        let now = Date(timeIntervalSince1970: 1710374400)

        // when
        let policy = WidgetStyleId.Style.custom(id: "c1").aiCommandWidgetRefreshPolicy(at: now)

        // then
        #expect(policy == .after(Date(timeIntervalSince1970: 1710374400 + 3600)))
    }

    @Test("기본 스타일 AICommand 위젯은 갱신하지 않는다")
    func aiCommandRefreshPolicy_whenDefault_neverRefreshes() {
        // given
        let now = Date(timeIntervalSince1970: 1710374400)

        // when
        let policy = WidgetStyleId.Style.default.aiCommandWidgetRefreshPolicy(at: now)

        // then
        #expect(policy == .never)
    }
}
