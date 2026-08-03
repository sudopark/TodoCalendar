//
//  DDayWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import TodoCalendarAppWidget


struct DDayWidgetViewModelProviderTests {

    private var utc: TimeZone { TimeZone(abbreviation: "UTC")! }

    private func makeProvider(
        stubTarget: DDayTargetEvent?
    ) -> DDayWidgetViewModelProvider {

        let eventFetchUsecase = StubCalendarEventsFetchUescase()
        eventFetchUsecase.stubDDayTarget = stubTarget

        let calendarSettingRepository = StubCalendarSettingRepository()
        calendarSettingRepository.saveTimeZone(self.utc)

        return DDayWidgetViewModelProvider(
            eventFetchUsecase: eventFetchUsecase,
            calendarSettingRepository: calendarSettingRepository,
            appSettingRepository: StubAppSettingRepository()
        )
    }

    private func makeTarget(
        time: EventTime,
        repeatOption: (any EventRepeatingOption)? = nil,
        targetId: DDayTargetEventId = .init(kind: .schedule, rawId: "s1")
    ) -> DDayTargetEvent {
        return DDayTargetEvent(
            targetId: targetId,
            name: "워크숍",
            time: time,
            repeatOption: repeatOption,
            repeatStartTime: repeatOption == nil ? nil : Date(timeIntervalSince1970: 0)
        )
    }
}


// MARK: - D-n 산출

extension DDayWidgetViewModelProviderTests {

    @Test("대상까지 남은 일수를 D-n으로 낸다")
    func getDDayModel_returnsDDayText() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(time: .at(14 * 24 * 3600))
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        #expect(model.eventTitle == "워크숍")
        #expect(model.ddayText == "D-14")
    }

    @Test("같은 날이면 D-Day")
    func getDDayModel_whenSameDay_returnsDDay() async throws {
        // given
        let now = Date(timeIntervalSince1970: 3600)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(time: .at(7200))
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        #expect(model.ddayText == "D-Day")
    }

    @Test("지난 대상이면 D+n")
    func getDDayModel_whenPast_returnsDPlus() async throws {
        // given
        let now = Date(timeIntervalSince1970: 3 * 24 * 3600)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(time: .at(0))
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        #expect(model.ddayText == "D+3")
    }
}


// MARK: - 반복 여부 표시

extension DDayWidgetViewModelProviderTests {

    @Test("반복 일정이면 반복옵션 요약이 채워진다")
    func getDDayModel_whenRepeating_fillsRepeatText() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(
                time: .at(24 * 3600),
                repeatOption: EventRepeatingOptions.EveryDay()
            )
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        #expect(model.isRepeating == true)
        #expect(model.repeatText.isEmpty == false)
    }

    @Test("반복이 아니면 반복옵션 요약이 비어 있다")
    func getDDayModel_whenNotRepeating_repeatTextIsEmpty() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(time: .at(24 * 3600))
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        #expect(model.isRepeating == false)
        #expect(model.repeatText.isEmpty == true)
    }
}


// MARK: - 시각 표시

extension DDayWidgetViewModelProviderTests {

    @Test("시각 있는 일정은 날짜와 시각을 모두 낸다")
    func getDDayModel_whenTimed_fillsBothTexts() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(time: .at(24 * 3600 + 7 * 3600))
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        #expect(model.dateText.isEmpty == false)
        #expect(model.timeText.isEmpty == false)
    }

    @Test("종일 일정은 시각 텍스트가 비어 있다")
    func getDDayModel_whenAllDay_timeTextIsEmpty() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let dayStart: TimeInterval = 24 * 3600
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(
                time: .allDay(dayStart..<(dayStart + 24 * 3600 - 1), secondsFromGMT: 0)
            )
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        #expect(model.timeText.isEmpty == true)
        #expect(model.dateText.isEmpty == false)
    }
}


// MARK: - 갱신 시각과 대상 없음

extension DDayWidgetViewModelProviderTests {

    @Test("갱신 시각은 유저 타임존의 다음 자정")
    func getDDayModel_refreshAfterIsNextMidnight() async throws {
        // given: UTC 기준 1970-01-01 10:00
        let now = Date(timeIntervalSince1970: 10 * 3600)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(time: .at(14 * 24 * 3600))
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then: 1970-01-02 00:00 UTC
        #expect(model.refreshAfter == Date(timeIntervalSince1970: 24 * 3600))
    }

    @Test("대상이 지정되지 않으면 안내 문구를 낸다")
    func getDDayModel_whenTargetIsNil_returnsGuide() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(stubTarget: nil)

        // when
        let model = try await provider.getDDayModel(for: now, target: nil)

        // then
        #expect(model.ddayText == "–")
        #expect(model.dateText.isEmpty == true)
        #expect(model.refreshAfter == Date(timeIntervalSince1970: 24 * 3600))
    }

    @Test("대상이 삭제돼 조회되지 않으면 안내 문구를 낸다")
    func getDDayModel_whenTargetNotFound_returnsGuide() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(stubTarget: nil)

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "removed")
        )

        // then
        #expect(model.ddayText == "–")
    }
}


// MARK: - 탭 링크

extension DDayWidgetViewModelProviderTests {

    @Test("일정은 해당 회차 상세 링크를 낸다")
    func getDDayModel_whenSchedule_linksToScheduleDetail() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(time: .at(14 * 24 * 3600))
        )

        // when
        let model = try await provider.getDDayModel(
            for: now, target: .init(kind: .schedule, rawId: "s1")
        )

        // then
        let link = try #require(model.link)
        #expect(link.absoluteString.contains("calendar/event/schedule") == true)
        #expect(link.absoluteString.contains("event_id=s1") == true)
    }

    @Test("공휴일은 해당 날짜 선택 링크를 낸다")
    func getDDayModel_whenHoliday_linksToCalendarDay() async throws {
        // given: UTC 기준 1970-01-15 00:00 = 14일 * 86400
        let now = Date(timeIntervalSince1970: 0)
        let dayStart: TimeInterval = 14 * 24 * 3600
        let holidayId = DDayTargetEventId(
            kind: .holiday, rawId: "KR::1970-01-15::테스트공휴일"
        )
        let provider = self.makeProvider(
            stubTarget: self.makeTarget(
                time: .period(dayStart..<(dayStart + 24 * 3600 - 1)),
                targetId: holidayId
            )
        )

        // when
        let model = try await provider.getDDayModel(for: now, target: holidayId)

        // then
        let link = try #require(model.link)
        #expect(link.absoluteString.contains("select=1970_01_15") == true)
    }

    @Test("대상이 지정되지 않으면 링크가 없다")
    func getDDayModel_whenTargetIsNil_hasNoLink() async throws {
        // given
        let now = Date(timeIntervalSince1970: 0)
        let provider = self.makeProvider(stubTarget: nil)

        // when
        let model = try await provider.getDDayModel(for: now, target: nil)

        // then
        #expect(model.link == nil)
    }
}


// MARK: - 잠금화면 표시 문구

extension DDayWidgetViewModelProviderTests {

    private func makeModel(title: String, dday: String) -> DDayWidgetViewModel {
        return DDayWidgetViewModel(
            eventTitle: title,
            ddayText: dday,
            dateText: "3월 15일 (월)",
            timeText: "",
            repeatText: ""
        )
    }

    @Test("inline 문구는 D-n으로 시작한다 — 잠금화면은 뒤에서부터 잘린다")
    func lockScreenInlineText_startsWithDDay() {
        // given
        let model = self.makeModel(title: "워크숍", dday: "D-14")

        // when
        let text = model.lockScreenInlineText

        // then
        #expect(text.hasPrefix("D-14") == true)
        #expect(text.contains("워크숍") == true)
    }

    @Test("제목이 비어 있으면 D-n만 낸다")
    func lockScreenInlineText_whenTitleIsEmpty_ddayOnly() {
        // given
        let model = self.makeModel(title: "", dday: "D-14")

        // when
        let text = model.lockScreenInlineText

        // then
        #expect(text == "D-14")
    }

    @Test("대상이 없으면 안내 문구를 낸다")
    func lockScreenInlineText_whenNoTarget_usesGuide() {
        // given
        let model = DDayWidgetViewModel.noTarget()

        // when
        let text = model.lockScreenInlineText

        // then
        #expect(text.contains(model.eventTitle) == true)
    }
}
