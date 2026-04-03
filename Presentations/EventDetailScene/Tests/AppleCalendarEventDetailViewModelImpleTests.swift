//
//  AppleCalendarEventDetailViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 4/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


final class AppleCalendarEventDetailViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter = SpyRouter()

    private let stubCalendarId = "cal:1"
    private let stubEventId = "event:1"

    private func makeViewModel() -> AppleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()

        let appleUsecase = StubAppleCalendarUsecase()
        appleUsecase.stubCalendarTags = [
            .init(id: stubCalendarId, name: "Work", colorHex: "#ff0000")
        ]
        appleUsecase.refreshCalendarTags()

        let start = Date(timeIntervalSince1970: 1748059200) // 2025-05-24 12:00 UTC
        let end = Date(timeIntervalSince1970: 1748145600)   // 2025-05-25 12:00 UTC
        appleUsecase.stubEvents = [
            AppleCalendar.Event(
                eventId: stubEventId,
                calendarId: stubCalendarId,
                name: "Team Meeting",
                eventTime: .period(start.timeIntervalSince1970..<end.timeIntervalSince1970),
                location: "Conference Room A"
            )
        ]

        let viewModel = AppleCalendarEventDetailViewModelImple(
            calendarId: stubCalendarId,
            eventId: stubEventId,
            appleCalendarUsecase: appleUsecase,
            calendarSettingUsecase: settingUsecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase()
        )
        viewModel.router = self.spyRouter
        return viewModel
    }

    private func makeViewModelWithNoLocation() -> AppleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        let appleUsecase = StubAppleCalendarUsecase()
        appleUsecase.stubCalendarTags = [.init(id: stubCalendarId, name: "Work", colorHex: nil)]
        appleUsecase.refreshCalendarTags()
        appleUsecase.stubEvents = [
            AppleCalendar.Event(
                eventId: stubEventId,
                calendarId: stubCalendarId,
                name: "Meeting",
                eventTime: .at(Date().timeIntervalSince1970),
                location: nil
            )
        ]
        let viewModel = AppleCalendarEventDetailViewModelImple(
            calendarId: stubCalendarId,
            eventId: stubEventId,
            appleCalendarUsecase: appleUsecase,
            calendarSettingUsecase: settingUsecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase()
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_provideEventName() async throws {
        // given
        let expect = expectConfirm("이벤트 이름 제공")
        let viewModel = self.makeViewModel()

        // when
        let name = try await self.firstOutput(expect, for: viewModel.eventName) {
            viewModel.refresh()
        }

        // then
        #expect(name == "Team Meeting")
    }

    @Test func viewModel_provideTimeText() async throws {
        // given
        let expect = expectConfirm("시간 정보 제공")
        let viewModel = self.makeViewModel()

        // when
        let time = try await self.firstOutput(expect, for: viewModel.timeText) {
            viewModel.refresh()
        }

        // then
        #expect(time != nil)
        switch time {
        case .period: break
        default: Issue.record("period 타입이어야 함")
        }
    }

    @Test func viewModel_provideLocation() async throws {
        // given
        let expect = expectConfirm("위치 정보 제공")
        let viewModel = self.makeViewModel()

        // when
        let location = try await self.firstOutput(expect, for: viewModel.location) {
            viewModel.refresh()
        }

        // then
        #expect(location == "Conference Room A")
    }

    @Test func viewModel_provideTagModel() async throws {
        // given
        let expect = expectConfirm("캘린더 태그 정보 제공")
        let viewModel = self.makeViewModel()

        // when
        let tagModel = try await self.firstOutput(expect, for: viewModel.tagModel) {
            viewModel.refresh()
        }

        // then
        let model = try #require(tagModel)
        #expect(model?.calendarId == stubCalendarId)
        #expect(model?.name == "Work")
    }

    @Test func viewModel_whenNoLocation_locationIsNil() async throws {
        // given
        let expect = expectConfirm("위치 없는 경우 nil 제공")
        let viewModel = self.makeViewModelWithNoLocation()

        // when
        let location = try await self.firstOutput(expect, for: viewModel.location) {
            viewModel.refresh()
        }

        // then
        let locationValue = try #require(location)
        #expect(locationValue == nil)
    }

    @Test func viewModel_close() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.close()

        // then
        #expect(self.spyRouter.didClosed == true)
    }
}

private final class SpyRouter: BaseSpyRouter, AppleCalendarEventDetailRouting, @unchecked Sendable {
    func routeToAppleCalendarApp(at interval: TimeInterval) { }
}
