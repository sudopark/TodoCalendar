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
        occurrenceEventId: String? = nil,
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
            eventId: occurrenceEventId ?? stubEventId,
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
        #expect(textValue.isEmpty == false)
        #expect(textValue != R.String.EventDetail.Repeating.notRepeatingTitle)
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


// MARK: - 반복 행 표시

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_whenNoRecurrence_providesNoRepeatText() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }

        // when
        let text = try await self.firstOutput(expectConfirm("반복 없음 텍스트"), for: viewModel.repeatText) {
            viewModel.refresh()
        }

        // then
        #expect(text == R.String.EventDetail.Repeating.notRepeatingTitle)
    }

    @Test func viewModel_whenRuleIsNotMappable_stillProvidesRuleText() async throws {
        // given — BYSETPOS 는 unsupportedKeys 로 잡혀 매핑이 실패하지만, 원본 규칙 텍스트는 그대로 보여야 한다
        let rruleText = "RRULE:FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO"
        let viewModel = self.makeViewModelWithOrigin { $0.recurrenceRules = [rruleText] }

        // when
        let text = try await self.firstOutput(expectConfirm("잠긴 규칙 텍스트"), for: viewModel.repeatText) {
            viewModel.refresh()
        }

        // then
        let expected = try #require(RRuleParser.parse(rruleText)).frequencyText()
        #expect(text == expected)
    }

    @Test func viewModel_whenRuleIsUnparsable_doesNotSayNoRepeat() async throws {
        // given — HOURLY 는 RRuleParser.Frequency 자체에 없어 parse 가 nil 을 낸다
        let viewModel = self.makeViewModelWithOrigin {
            $0.recurrenceRules = ["RRULE:FREQ=HOURLY;INTERVAL=2"]
        }

        // when
        let text = try await self.firstOutput(expectConfirm("파싱 불가 규칙 텍스트"), for: viewModel.repeatText) {
            viewModel.refresh()
        }

        // then — "반복 없음"이 아니라 원본 규칙 텍스트를 그대로 보여준다
        #expect(text != R.String.EventDetail.Repeating.notRepeatingTitle)
        #expect(text == "FREQ=HOURLY;INTERVAL=2")
    }

    @Test func viewModel_whenMultipleRules_showsLockedRuleText() async throws {
        // given — 첫 규칙은 단독이면 매핑 가능하고, 잠금 문구(frequencyText)와 편집 문구(선택 화면 문구)가 갈리는 규칙이다
        let firstRule = "RRULE:FREQ=WEEKLY;BYDAY=TU"
        let viewModel = self.makeViewModelWithOrigin {
            $0.recurrenceRules = [firstRule, "RRULE:FREQ=WEEKLY;BYDAY=SA"]
        }

        // when
        let text = try await self.firstOutput(expectConfirm("복수 규칙 텍스트"), for: viewModel.repeatText) {
            viewModel.refresh()
        }

        // then — 편집 문구가 아니라 잠금 경로의 원본 규칙 문구를 보여준다
        let lockedText = try #require(RRuleParser.parse(firstRule)).frequencyText()
        #expect(text == lockedText)
        #expect(text != "Every Tuesday")
    }

    @Test func viewModel_whenRepeatSelected_repeatTextFollowsSelection() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        let newRepeating = EventRepeating(
            repeatingStartTime: 1_748_400_000,
            repeatOption: EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        )
        viewModel.selectEventRepeatOption(didSelect: .init(text: "매 3일", repeating: newRepeating))
        let text = try await self.firstOutput(expectConfirm("선택 반영된 텍스트"), for: viewModel.repeatText)

        // then
        #expect(text != R.String.EventDetail.Repeating.notRepeatingTitle)
    }
}


// MARK: - 반복 편집 진입

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_whenRuleIsNotMappable_selectRepeatOptionShowsToast() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin {
            $0.recurrenceRules = ["RRULE:FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO"]
        }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.selectRepeatOption()

        // then
        #expect(
            self.spyRouter.didShowToastWithMessage
                == "eventDetail::appleCalendarEvent::notEditableField::message".localized()
        )
        #expect(self.spyRouter.didRouteToRepeatOptionSelectWith == nil)
    }

    @Test func viewModel_whenRuleIsMappable_selectRepeatOptionRoutes() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin {
            $0.recurrenceRules = ["RRULE:FREQ=DAILY;INTERVAL=5"]
        }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.selectRepeatOption()

        // then
        #expect(self.spyRouter.didRouteToRepeatOptionSelectWith?.previousSelected != nil)
        #expect(self.spyRouter.didShowToastWithMessage == nil)
    }

    @Test func viewModel_whenNoRecurrence_selectRepeatOptionRoutes() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.selectRepeatOption()

        // then
        #expect(self.spyRouter.didRouteToRepeatOptionSelectWith != nil)
        #expect(self.spyRouter.didRouteToRepeatOptionSelectWith?.previousSelected == nil)
    }

    @Test func viewModel_whenMultipleRules_selectRepeatOptionShowsToast() async throws {
        // given — 첫 규칙만 보면 매핑 가능해 잠금이 풀릴 수 있는 조합. 저장이 규칙 배열을 한 줄로
        // 덮어써 둘째 규칙이 사라지므로 규칙 집합 단위로 잠겨야 한다
        let viewModel = self.makeViewModelWithOrigin {
            $0.isRepeating = true
            $0.recurrenceRules = ["RRULE:FREQ=DAILY;INTERVAL=5", "RRULE:FREQ=WEEKLY;BYDAY=SA"]
        }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.selectRepeatOption()

        // then
        #expect(
            self.spyRouter.didShowToastWithMessage
                == "eventDetail::appleCalendarEvent::notEditableField::message".localized()
        )
        #expect(self.spyRouter.didRouteToRepeatOptionSelectWith == nil)
    }

    @Test func viewModel_whenWritableUnknown_selectRepeatOptionIsIgnored() async throws {
        // given — 쓰기 가능 판정 전(nil)은 필드 입력과 같은 fail-closed 게이팅을 탄다
        let viewModel = self.makeViewModelWithOrigin(isWritable: nil) { _ in }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.selectRepeatOption()

        // then
        #expect(self.spyRouter.didRouteToRepeatOptionSelectWith == nil)
        #expect(self.spyRouter.didShowToastWithMessage == nil)
    }
}


// MARK: - 반복 규칙 저장

extension AppleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_whenRepeatChanged_savesToMasterWithFutureScope() async throws {
        // given — 반복 회차 상세(합성 eventId)에서 규칙을 바꾸는 상황
        let viewModel = self.makeViewModelWithOrigin(occurrenceEventId: "\(stubEventId)#occ:100") {
            $0.isRepeating = true
            $0.recurrenceRules = ["RRULE:FREQ=DAILY;INTERVAL=5"]
        }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        let newRepeating = EventRepeating(
            repeatingStartTime: 1_748_400_000,
            repeatOption: EventRepeatingOptions.EveryDay() |> \.interval .~ 3
        )
        viewModel.selectEventRepeatOption(didSelect: .init(text: "매 3일", repeating: newRepeating))
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then — 회차가 아니라 마스터를 대상으로, 범위 선택 없이 이후 회차 전체에 적용
        #expect(self.spyRouter.didShowActionSheetWith == nil)
        #expect(self.lastAppleUsecase.didUpdateEventWith?.eventId == stubEventId)
        #expect(self.lastAppleUsecase.didUpdateEventWith?.scope == .thisAndFuture)
        let rules = self.lastAppleUsecase.didUpdateEventWith?.params.recurrenceRules
        #expect(rules?.count == 1)
        #expect(rules?.first?.hasPrefix("RRULE:FREQ=DAILY;INTERVAL=3") == true)
    }

    @Test func viewModel_whenRepeatRemoved_sendsEmptyRecurrenceRules() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin {
            $0.isRepeating = true
            $0.recurrenceRules = ["RRULE:FREQ=DAILY;INTERVAL=5"]
        }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.selectEventRepeatOptionNotRepeat()
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then — nil(안 건드림)이 아니라 빈 배열(반복 해제)이 실려야 한다
        #expect(self.lastAppleUsecase.didUpdateEventWith?.params.recurrenceRules == [])
    }

    @Test func viewModel_whenRepeatAddedToNonRepeatingEvent_sendsNewRule() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { $0.isRepeating = false }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        let newRepeating = EventRepeating(
            repeatingStartTime: 1_748_400_000,
            repeatOption: EventRepeatingOptions.EveryDay() |> \.interval .~ 2
        )
        viewModel.selectEventRepeatOption(didSelect: .init(text: "매 2일", repeating: newRepeating))
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        let rules = self.lastAppleUsecase.didUpdateEventWith?.params.recurrenceRules
        #expect(rules?.first?.hasPrefix("RRULE:FREQ=DAILY;INTERVAL=2") == true)
        #expect(self.lastAppleUsecase.didUpdateEventWith?.scope == .thisAndFuture)
    }

    @Test func viewModel_whenOnlyNameChanged_showsScopeSheet() async throws {
        // given — 반복 이벤트지만 규칙은 그대로인 경우 기존 범위 선택 동선을 유지한다
        let viewModel = self.makeViewModelWithOrigin(occurrenceEventId: "\(stubEventId)#occ:100") {
            $0.isRepeating = true
            $0.recurrenceRules = ["RRULE:FREQ=DAILY;INTERVAL=5"]
        }
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "new name")
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowActionSheetWith?.actions.count == 3)
        #expect(self.lastAppleUsecase.didUpdateEventWith == nil)
    }
}


// MARK: - 애플이 UTC 하루 끝으로 저장한 반복 종료일 표시

extension AppleCalendarEventDetailViewModelImpleTests {

    private func repeatText(forRule rule: String) async throws -> String? {
        let viewModel = self.makeViewModelWithOrigin { $0.recurrenceRules = [rule] }
        return try await self.firstOutput(expectConfirm("반복 텍스트"), for: viewModel.repeatText) {
            viewModel.refresh()
        }
    }

    @Test func viewModel_whenUntilIsUTCDayEnd_showsSameEndDateAsLocalInstant() async throws {
        // given - 같은 9/30 종료를 애플식(UTC 하루 끝)과 로컬 instant 로 각각 표현
        let appleEncodedRule = "RRULE:FREQ=DAILY;INTERVAL=1;UNTIL=20260930T235959Z"
        let localInstantRule = "RRULE:FREQ=DAILY;INTERVAL=1;UNTIL=20260930T145959Z"

        // when
        let appleEncodedText = try await self.repeatText(forRule: appleEncodedRule)
        let localInstantText = try await self.repeatText(forRule: localInstantRule)

        // then
        #expect(appleEncodedText == localInstantText)
    }

    @Test func viewModel_whenLockedRuleUntilIsUTCDayEnd_showsSameEndDateAsLocalInstant() async throws {
        // given - BYSETPOS 로 매핑이 잠긴 규칙도 같은 종료일로 보여야 한다
        let appleEncodedRule = "RRULE:FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO;UNTIL=20260930T235959Z"
        let localInstantRule = "RRULE:FREQ=MONTHLY;BYSETPOS=-1;BYDAY=MO;UNTIL=20260930T145959Z"

        // when
        let appleEncodedText = try await self.repeatText(forRule: appleEncodedRule)
        let localInstantText = try await self.repeatText(forRule: localInstantRule)

        // then
        #expect(appleEncodedText == localInstantText)
    }
}


private final class SpyRouter: BaseSpyRouter, AppleCalendarEventDetailRouting, @unchecked Sendable {
    func routeToAppleCalendarApp(at interval: TimeInterval) { }

    var didRouteToRepeatOptionSelectWith: (selectTime: Date, previousSelected: EventRepeating?)?
    func routeToEventRepeatOptionSelect(
        selectTime: Date,
        previousSelected repeating: EventRepeating?,
        listener: (any SelectEventRepeatOptionSceneListener)?
    ) {
        self.didRouteToRepeatOptionSelectWith = (selectTime, repeating)
    }

    var didShareText: String?
    func showShareSheet(text: String) {
        self.didShareText = text
    }
}


private final class MockAppleCalendarUsecase: StubAppleCalendarUsecase, @unchecked Sendable {
    let isWritableSubject = CurrentValueSubject<Bool?, Never>(true)
    override func isCalendarWritable(_ calendarId: String) -> AnyPublisher<Bool?, Never> {
        return self.isWritableSubject.eraseToAnyPublisher()
    }
}


// MARK: - 공유

extension AppleCalendarEventDetailViewModelImpleTests {

    private func shareFieldLabel(_ key: String) -> String {
        return "event_detail::share::field::\(key)".localized()
    }

    private var shareTagLabel: String { self.shareFieldLabel("calendar") }

    @Test func viewModel_whenShare_composeTextWithVisibleFields() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin {
            $0.location = "Conference Room A"
            $0.url = "https://example.com"
            $0.notes = "메모"
        }
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(10))
        let time = try await self.firstOutput(expectConfirm("현재 시간값"), for: viewModel.timeText)
        let expectedTimeText = time.flatMap { $0 }.map { EventDetailShareTextBuilder().timeText(from: $0) }

        // when
        viewModel.share()
        try await Task.sleep(for: .milliseconds(10))

        // then
        let text = try #require(self.spyRouter.didShareText)
        let lines = text.components(separatedBy: "\n")
        #expect(lines.first == "Meeting")
        #expect(lines.contains("\(self.shareFieldLabel("time")): \(expectedTimeText ?? "")"))
        #expect(lines.contains("\(self.shareTagLabel): Work"))
        #expect(lines.contains("\(self.shareFieldLabel("place")): Conference Room A"))
        #expect(lines.contains("\(self.shareFieldLabel("url")): https://example.com"))
        #expect(lines.contains("\(self.shareFieldLabel("memo")): 메모"))
    }

    @Test func viewModel_whenShareAfterEnterName_shareEditedName() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(10))
        viewModel.enter(name: "수정된 이름")

        // when
        viewModel.share()
        try await Task.sleep(for: .milliseconds(10))

        // then
        let text = try #require(self.spyRouter.didShareText)
        let lines = text.components(separatedBy: "\n")
        #expect(lines.first == "수정된 이름")
        #expect(!lines.contains("Meeting"))
    }

    @Test func viewModel_whenShareNotRepeatingEvent_withoutRepeatLine() async throws {
        // given
        let viewModel = self.makeViewModelWithOrigin { _ in }
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(10))

        // when
        viewModel.share()
        try await Task.sleep(for: .milliseconds(10))

        // then
        let text = try #require(self.spyRouter.didShareText)
        let lines = text.components(separatedBy: "\n")
        #expect(!lines.contains(where: { $0.hasPrefix("\(self.shareFieldLabel("repeating")):") }))
    }
}
