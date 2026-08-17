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
    private var lastAppleUsecase: StubAppleCalendarUsecase!

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
        self.lastAppleUsecase = appleUsecase

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
        isWritable: Bool? = true,
        shouldFailWrite: Bool = false,
        eventTime: EventTime = .at(Date().timeIntervalSince1970),
        _ configure: (inout AppleCalendar.EventOrigin) -> Void = { _ in }
    ) -> AppleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        let appleUsecase = StubAppleCalendarUsecase()
        appleUsecase.stubCalendarTags = [.init(id: stubCalendarId, name: "Work", colorHex: nil)]
        appleUsecase.refreshCalendarTags()
        appleUsecase.stubIsCalendarWritable = isWritable
        appleUsecase.shouldFailWrite = shouldFailWrite
        var origin = AppleCalendar.EventOrigin(
            eventId: stubEventId,
            originalEventId: stubEventId,
            calendarId: stubCalendarId,
            name: "Meeting",
            eventTime: eventTime
        )
        configure(&origin)
        appleUsecase.stubEventOrigin = origin
        self.lastAppleUsecase = appleUsecase
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

    private func makeViewModelWithMockUsecase() -> (AppleCalendarEventDetailViewModelImple, MockAppleCalendarUsecase) {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        let appleUsecase = MockAppleCalendarUsecase()
        appleUsecase.stubCalendarTags = [.init(id: stubCalendarId, name: "Work", colorHex: nil)]
        appleUsecase.refreshCalendarTags()
        let origin = AppleCalendar.EventOrigin(
            eventId: stubEventId,
            originalEventId: stubEventId,
            calendarId: stubCalendarId,
            name: "Meeting",
            eventTime: .at(Date().timeIntervalSince1970)
        )
        appleUsecase.stubEventOrigin = origin
        self.lastAppleUsecase = appleUsecase
        let viewModel = AppleCalendarEventDetailViewModelImple(
            calendarId: stubCalendarId,
            eventId: stubEventId,
            appleCalendarUsecase: appleUsecase,
            calendarSettingUsecase: settingUsecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase()
        )
        viewModel.router = self.spyRouter
        return (viewModel, appleUsecase)
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


// MARK: - isEditable / readOnlyCalendarMessage 노출

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_whenCalendarIsReadOnly_isNotEditable() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin(isWritable: false) { _ in }

        // when
        let isEditable = try await self.firstOutput(expectConfirm("isEditable"), for: viewModel.isEditable)
        let message = try await self.firstOutput(expectConfirm("readOnlyCalendarMessage"), for: viewModel.readOnlyCalendarMessage) ?? nil

        // then
        #expect(isEditable == false)
        #expect(message != nil)
    }

    @Test func viewModel_whenCalendarIsWritable_hasNoReadOnlyMessage() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin(isWritable: true) { _ in }

        // when
        let isEditable = try await self.firstOutput(expectConfirm("isEditable"), for: viewModel.isEditable)
        let message = try await self.firstOutput(expectConfirm("readOnlyCalendarMessage"), for: viewModel.readOnlyCalendarMessage) ?? nil

        // then
        #expect(isEditable == true)
        #expect(message == nil)
    }
}


// MARK: - 읽기 전용 캘린더·판정 전(unknown)에는 입력이 무시된다

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_whenReadOnly_ignoresFieldInput() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin(isWritable: false) { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "changed")
        let isSavable = try await self.firstOutput(expectConfirm("isSavable"), for: viewModel.isSavable)

        // then
        #expect(isSavable == false)
    }

    @Test func viewModel_whenWritableUnknown_ignoresFieldInput() async throws {
        // given — isCalendarWritable 판정이 아직 도착하지 않은 상태(nil). 구글과 달리 애플은 이 상태도 막는다(fail-closed)
        let viewModel = self.makeViewModelWithOrigin(isWritable: nil) { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "changed")
        let isSavable = try await self.firstOutput(expectConfirm("isSavable"), for: viewModel.isSavable)

        // then
        #expect(isSavable == false)
    }
}


// MARK: - 저장 가능 여부(isSavable)

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_whenNoChange_isNotSavable() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        let isSavable = try await self.firstOutput(expectConfirm("isSavable"), for: viewModel.isSavable)

        // then
        #expect(isSavable == false)
    }

    @Test func viewModel_whenNameIsEmpty_isNotSavable() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "")
        let isSavable = try await self.firstOutput(expectConfirm("isSavable"), for: viewModel.isSavable)

        // then
        #expect(isSavable == false)
    }

    @Test func viewModel_whenTimeRangeIsInvalid_isNotSavable() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.timeText) {
            viewModel.refresh()
        }

        // when — 종료 시각을 시작 시각보다 앞으로 이동
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        viewModel.selectEndTime(end)
        viewModel.selectStartTime(start)
        let isSavable = try await self.firstOutput(expectConfirm("isSavable"), for: viewModel.isSavable)

        // then
        #expect(isSavable == false)
    }
}


// MARK: - 필드 입력이 presenter 에 반영된다

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_enterFields_updatesPresenters() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "new name")
        viewModel.enter(location: "new location")
        viewModel.enter(url: "https://example.com")
        viewModel.enter(notes: "new notes")

        // then
        let name = try await self.firstOutput(expectConfirm("name"), for: viewModel.eventName)
        let location = try await self.firstOutput(expectConfirm("location"), for: viewModel.location)
        let url = try await self.firstOutput(expectConfirm("url"), for: viewModel.url)
        let notes = try await self.firstOutput(expectConfirm("notes"), for: viewModel.notes)
        #expect(name == "new name")
        #expect(location == "new location")
        #expect(url == "https://example.com")
        #expect(notes == "new notes")
    }
}


// MARK: - d-day 는 편집된 시간을 따른다

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func ddayText_followsEditedTimeNotOrigin() async throws {
        // given — countDays 스텁은 입력값과 무관하게 항상 [-4, 0, 4]를 방출하므로,
        // 시간 편집 후 재구독(스트림 재발행) 여부로 소스 전환을 판별한다
        let expect = expectConfirm("edited time 기준으로 d-day 재계산")
        expect.count = 6
        let viewModel = self.makeViewModelWithOrigin { _ in }

        // when
        let days = try await self.outputs(expect, for: viewModel.ddayText) {
            viewModel.refresh()
            viewModel.selectStartTime(Date(timeIntervalSince1970: 1_748_400_000))
        }

        // then
        #expect(days == ["D+4", "D-Day", "D-4", "D+4", "D-Day", "D-4"])
    }
}


// MARK: - refresh() 재진입 시 편집 중인 변경사항 보존

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func refresh_whenHasUnsavedChanges_doesNotDiscardThem() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "edited name")

        // when
        viewModel.refresh()
        let name = try await self.firstOutput(expectConfirm("refresh 후에도 편집값 유지"), for: viewModel.eventName)

        // then
        #expect(name == "edited name")
    }
}


// MARK: - 저장

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_saveNonRepeatingEvent_updatesWithThisEventScope() async throws {
        // given — location/url/notes 를 origin 부터 non-nil 로 채워, 안 건드린 필드가 params 에서
        // 빠지는지(nil 로 안 실리는지)를 "원래도 nil" 케이스와 구분해 검증한다
        let viewModel = self.makeViewModelWithOrigin {
            $0.isRepeating = false
            $0.location = "Origin Location"
            $0.url = "https://origin.example.com"
            $0.notes = "Origin notes"
        }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastAppleUsecase.didUpdateEventWith?.eventId == stubEventId)
        #expect(self.lastAppleUsecase.didUpdateEventWith?.scope == .thisEventOnly)
        let params = self.lastAppleUsecase.didUpdateEventWith?.params
        #expect(params?.name == "new name")
        #expect(params?.location == nil)
        #expect(params?.url == nil)
        #expect(params?.notes == nil)
        #expect(params?.time == nil)
    }

    @Test func viewModel_saveAfterEditingStartTime_sendsEditedTimeInParams() async throws {
        // given
        let start = "2026-08-13 09:00:00".date(form: "yyyy-MM-dd HH:mm:ss", timeZoneAbbre: "KST")
        let end = "2026-08-13 10:00:00".date(form: "yyyy-MM-dd HH:mm:ss", timeZoneAbbre: "KST")
        let viewModel = self.makeViewModelWithOrigin(
            eventTime: .period(start.timeIntervalSince1970..<end.timeIntervalSince1970)
        ) { $0.isRepeating = false }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when — 시작 시각만 한 시간 당김
        let newStart = "2026-08-13 08:00:00".date(form: "yyyy-MM-dd HH:mm:ss", timeZoneAbbre: "KST")
        viewModel.selectStartTime(newStart)
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then — 편집된 시각이 실려야 하고, 원본 시각이 실리면 안 된다
        let editedTime = EventTime.period(newStart.timeIntervalSince1970..<end.timeIntervalSince1970)
        let originalTime = EventTime.period(start.timeIntervalSince1970..<end.timeIntervalSince1970)
        let params = self.lastAppleUsecase.didUpdateEventWith?.params
        #expect(params?.time == editedTime)
        #expect(params?.time != originalTime)
    }

    @Test func viewModel_saveRepeatingEvent_showsScopeActionSheet() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = true }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then — 이번 일정만 / 이후 모든 일정 + 취소
        #expect(self.spyRouter.didShowActionSheetWith?.actions.count == 3)
    }

    @Test func viewModel_saveRepeatingEvent_onlyThisTime_usesThisEventOnlyScope() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = true }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::appleCalendarEvent::repeating::onlyThisTime::button".localized()
            })
        }

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastAppleUsecase.didUpdateEventWith?.scope == .thisEventOnly)
    }

    @Test func viewModel_saveRepeatingEvent_thisAndFuture_usesThisAndFutureScope() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = true }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::appleCalendarEvent::repeating::thisAndFuture::button".localized()
            })
        }

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastAppleUsecase.didUpdateEventWith?.scope == .thisAndFuture)
    }

    @Test func viewModel_saveSuccess_showsToastAndClosesScene() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = false }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowToastWithMessage != nil)
        #expect(self.spyRouter.didClosed == true)
    }

    @Test func viewModel_saveReadOnlyCalendar_doesNothing() async throws {
        // given — enter(name:) 는 updateCurrentFields 의 읽기 전용 가드에서 이미 무시된다
        let viewModel = self.makeViewModelWithOrigin(isWritable: false) { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastAppleUsecase.didUpdateEventWith == nil)
        #expect(self.spyRouter.didShowActionSheetWith == nil)
        #expect(self.spyRouter.didClosed == nil)
    }

    @Test func viewModel_saveWhenWritePermissionRevokedAfterEdit_doesNothing() async throws {
        // given — 쓰기 가능한 상태로 편집을 마쳤지만, 저장 직전 권한이 회수된 경우
        let (viewModel, mockUsecase) = self.makeViewModelWithMockUsecase()
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")
        let isSavableBeforeRevoke = try await self.firstOutput(
            expectConfirm("편집 직후 저장 가능"), for: viewModel.isSavable
        )
        #expect(isSavableBeforeRevoke == true)

        // when
        mockUsecase.isWritableSubject.send(false)
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(mockUsecase.didUpdateEventWith == nil)
        #expect(self.spyRouter.didShowActionSheetWith == nil)
        #expect(self.spyRouter.didClosed == nil)
    }

    @Test func viewModel_saveFailure_showsErrorAndKeepsScene() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin(shouldFailWrite: true) { $0.isRepeating = false }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowError != nil)
        #expect(self.spyRouter.didClosed != true)
        let isSavingNow = try await self.firstOutput(expectConfirm("isSaving false"), for: viewModel.isSaving)
        #expect(isSavingNow == false)
    }
}


// MARK: - 삭제

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_removeNonRepeatingEvent_confirmsThenRemoves() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = false }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowConfirmWith != nil)
        #expect(self.lastAppleUsecase.didRemoveEventWith?.eventId == stubEventId)
        #expect(self.lastAppleUsecase.didRemoveEventWith?.scope == .thisEventOnly)
        #expect(self.spyRouter.didClosed == true)
    }

    @Test func viewModel_removeRepeatingEvent_showsScopeActionSheet() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = true }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowConfirmWith == nil)
        #expect(self.spyRouter.didShowActionSheetWith?.actions.count == 3)
    }

    @Test func viewModel_removeRepeatingEvent_onlyThisTime_usesThisEventOnlyScope() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = true }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::appleCalendarEvent::repeating::onlyThisTime::button".localized()
            })
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastAppleUsecase.didRemoveEventWith?.scope == .thisEventOnly)
    }

    @Test func viewModel_removeRepeatingEvent_thisAndFuture_usesThisAndFutureScope() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = true }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::appleCalendarEvent::repeating::thisAndFuture::button".localized()
            })
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastAppleUsecase.didRemoveEventWith?.scope == .thisAndFuture)
    }

    @Test func viewModel_removeReadOnlyCalendar_doesNothing() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin(isWritable: false) { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastAppleUsecase.didRemoveEventWith == nil)
        #expect(self.spyRouter.didShowConfirmWith == nil)
        #expect(self.spyRouter.didClosed == nil)
    }
}


// MARK: - 수정 불가 항목 안내

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func selectNotEditableField_showsGuideToast() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.selectNotEditableField()

        // then
        #expect(self.spyRouter.didShowToastWithMessage != nil)
    }
}


private final class SpyRouter: BaseSpyRouter, AppleCalendarEventDetailRouting, @unchecked Sendable {
    func routeToAppleCalendarApp(at interval: TimeInterval) { }
    func openURL(_ urlString: String) { }
}


private final class MockAppleCalendarUsecase: StubAppleCalendarUsecase, @unchecked Sendable {
    let isWritableSubject = CurrentValueSubject<Bool?, Never>(true)
    override func isCalendarWritable(_ calendarId: String) -> AnyPublisher<Bool?, Never> {
        return self.isWritableSubject.eraseToAnyPublisher()
    }
}
