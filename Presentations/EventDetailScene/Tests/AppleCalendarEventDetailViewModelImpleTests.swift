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

        let start = Date(timeIntervalSince1970: 1748059200)
        let end = Date(timeIntervalSince1970: 1748145600)
        var origin = AppleCalendar.EventOrigin(
            eventId: stubEventId,
            originalEventId: stubEventId,
            calendarId: stubCalendarId,
            name: "Team Meeting",
            eventTime: .period(start.timeIntervalSince1970..<end.timeIntervalSince1970)
        )
        origin.location = "Conference Room A"
        appleUsecase.stubEventOrigin = origin

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

    private func makeViewModelWithOrigin(
        _ configure: (inout AppleCalendar.EventOrigin) -> Void = { _ in }
    ) -> AppleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        let appleUsecase = StubAppleCalendarUsecase()
        appleUsecase.stubCalendarTags = [.init(id: stubCalendarId, name: "Work", colorHex: nil)]
        appleUsecase.refreshCalendarTags()
        var origin = AppleCalendar.EventOrigin(
            eventId: stubEventId,
            originalEventId: stubEventId,
            calendarId: stubCalendarId,
            name: "Meeting",
            eventTime: .at(Date().timeIntervalSince1970)
        )
        configure(&origin)
        appleUsecase.stubEventOrigin = origin
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
        let viewModel = self.makeViewModelWithOrigin { _ in }

        // when
        let location = try await self.firstOutput(expect, for: viewModel.location) {
            viewModel.refresh()
        }

        // then
        let locationValue = try #require(location)
        #expect(locationValue == nil)
    }

    @Test func viewModel_provideURL() async throws {
        // given
        let expect = expectConfirm("URL 정보 제공")
        let viewModel = self.makeViewModelWithOrigin {
            $0.url = "https://example.com"
        }

        // when
        let url = try await self.firstOutput(expect, for: viewModel.url) {
            viewModel.refresh()
        }

        // then
        let urlValue = try #require(url)
        #expect(urlValue == "https://example.com")
    }

    @Test func viewModel_whenEmptyURL_returnsNil() async throws {
        // given
        let expect = expectConfirm("빈 URL은 nil 반환")
        let viewModel = self.makeViewModelWithOrigin {
            $0.url = ""
        }

        // when
        let url = try await self.firstOutput(expect, for: viewModel.url) {
            viewModel.refresh()
        }

        // then
        let urlValue = try #require(url)
        #expect(urlValue == nil)
    }

    @Test func viewModel_provideNotes() async throws {
        // given
        let expect = expectConfirm("메모 정보 제공")
        let viewModel = self.makeViewModelWithOrigin {
            $0.notes = "Meeting notes"
        }

        // when
        let notes = try await self.firstOutput(expect, for: viewModel.notes) {
            viewModel.refresh()
        }

        // then
        let notesValue = try #require(notes)
        #expect(notesValue == "Meeting notes")
    }

    @Test func viewModel_provideRepeatText() async throws {
        // given
        let expect = expectConfirm("반복 규칙 텍스트 제공")
        let viewModel = self.makeViewModelWithOrigin {
            $0.recurrenceRules = ["RRULE:FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,FR"]
        }

        // when
        let text = try await self.firstOutput(expect, for: viewModel.repeatText) {
            viewModel.refresh()
        }

        // then
        let textValue = try #require(text)
        #expect(textValue != nil)
        #expect(textValue?.isEmpty == false)
    }

    @Test func viewModel_whenNoRepeatRules_repeatTextIsNil() async throws {
        // given
        let expect = expectConfirm("반복 규칙 없으면 nil")
        let viewModel = self.makeViewModelWithOrigin { _ in }

        // when
        let text = try await self.firstOutput(expect, for: viewModel.repeatText) {
            viewModel.refresh()
        }

        // then
        let textValue = try #require(text)
        #expect(textValue == nil)
    }

    @Test func viewModel_provideAttendees() async throws {
        // given
        let expect = expectConfirm("참석자 목록 제공")
        let viewModel = self.makeViewModelWithOrigin {
            $0.attendees = [
                .init(name: "Alice", email: "alice@test.com"),
                .init(name: "Bob", email: "bob@test.com")
            ]
        }

        // when
        let attendees = try await self.firstOutput(expect, for: viewModel.attendees) {
            viewModel.refresh()
        }

        // then
        let list = try #require(attendees)
        #expect(list.count == 2)
        #expect(list.first?.name == "Alice")
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
    func openURL(_ urlString: String) { }
}
