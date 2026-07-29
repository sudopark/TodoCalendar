//
//  DDayWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import TestDoubles

@testable import TodoCalendarApp


struct DDayWidgetViewModelProviderTests {

    private var utc: TimeZone { TimeZone(abbreviation: "UTC")! }

    // 2026-07-27 00:00 UTC
    private var now: Date { Date(timeIntervalSince1970: 1785110400) }

    private func makeProvider(
        target: DDayTargetEvent? = nil
    ) -> DDayWidgetViewModelProvider {

        let usecase = StubCalendarEventsFetchUescase()
        usecase.stubDDayTarget = target

        let calendarSettingRepository = StubCalendarSettingRepository()
        calendarSettingRepository.saveTimeZone(self.utc)

        return DDayWidgetViewModelProvider(
            eventFetchUsecase: usecase,
            calendarSettingRepository: calendarSettingRepository,
            appSettingRepository: StubAppSettingRepository()
        )
    }
}

// MARK: - 대상이 있을 때

extension DDayWidgetViewModelProviderTests {

    @Test("14일 뒤 이벤트는 D-14")
    func provider_whenTargetIsFuture_showsDMinus() async throws {
        // given
        let after14Days = self.now.addingTimeInterval(3600 * 24 * 14)
        let target = DDayTargetEvent(
            targetId: .init(eventId: "s1", isTodo: false),
            name: "워크숍",
            time: .at(after14Days.timeIntervalSince1970)
        )
        let provider = self.makeProvider(target: target)
        // when
        let model = try await provider.getDDayModel(
            for: self.now, target: .init(eventId: "s1", isTodo: false)
        )
        // then
        #expect(model.eventTitle == "워크숍")
        #expect(model.ddayText == "D-14")
    }

    @Test("오늘 이벤트는 D-Day")
    func provider_whenTargetIsToday_showsDDay() async throws {
        // given
        let target = DDayTargetEvent(
            targetId: .init(eventId: "s1", isTodo: false),
            name: "오늘",
            time: .at(self.now.timeIntervalSince1970 + 3600)
        )
        let provider = self.makeProvider(target: target)
        // when
        let model = try await provider.getDDayModel(
            for: self.now, target: .init(eventId: "s1", isTodo: false)
        )
        // then
        #expect(model.ddayText == "D-Day")
    }

    @Test("갱신 시각은 유저 타임존 기준 다음 자정")
    func provider_refreshAfterIsNextMidnightInUserTimeZone() async throws {
        // given
        let target = DDayTargetEvent(
            targetId: .init(eventId: "s1", isTodo: false),
            name: "워크숍",
            time: .at(self.now.timeIntervalSince1970 + 3600 * 24 * 14)
        )
        let provider = self.makeProvider(target: target)
        // when
        let model = try await provider.getDDayModel(
            for: self.now.addingTimeInterval(3600 * 5), target: .init(eventId: "s1", isTodo: false)
        )
        // then
        #expect(model.refreshAfter == self.now.addingTimeInterval(3600 * 24))
    }
}

// MARK: - 대상이 없을 때

extension DDayWidgetViewModelProviderTests {

    @Test("대상 미지정이면 안내 문구")
    func provider_whenNoTarget_showsGuideText() async throws {
        // given
        let provider = self.makeProvider(target: nil)
        // when
        let model = try await provider.getDDayModel(for: self.now, target: nil)
        // then
        #expect(model.ddayText == "–")
        #expect(model.targetDateText.isEmpty)
    }
}
