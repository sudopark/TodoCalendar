//
//  GoogleCalendarEventEditViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 8/13/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Scenes
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


final class GoogleCalendarEventEditViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter = SpyRouter()
    private let spyListener = SpyListener()

    private func makeViewModel(
        recurringEventId: String? = nil,
        htmlLink: String? = "https://calendar.google.com/event?eid=instance_id"
    ) -> (GoogleCalendarEventEditViewModelImple, StubGoogleCalendarUsecase) {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()

        let start = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2026-08-13T10:00:00+09:00"
        let end = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2026-08-13T11:00:00+09:00"
        let origin = GoogleCalendar.EventOrigin(id: "instance_id", summary: "origin name")
            |> \.start .~ start
            |> \.end .~ end
            |> \.location .~ "origin location"
            |> \.description .~ "origin memo"
            |> \.colorId .~ "3"
            |> \.recurringEventId .~ recurringEventId
            |> \.htmlLink .~ htmlLink

        let calendarUsecase = StubGoogleCalendarUsecase()
        calendarUsecase.stubDetail = origin

        let viewModel = GoogleCalendarEventEditViewModelImple(
            calendarId: "calendar_id", accountId: "account_id", eventId: "instance_id",
            googleCalendarUsecase: calendarUsecase,
            calendarSettingUsecase: settingUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return (viewModel, calendarUsecase)
    }

    private func waitSaveCompleted(_ action: () -> Void) async throws {
        try await confirmation("저장 완료 대기") { confirm in
            self.spyRouter.didCloseCallback = { confirm.confirm() }
            action()
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    private func makeAllDayViewModel(
        startDate: String, endDate: String
    ) -> (GoogleCalendarEventEditViewModelImple, StubGoogleCalendarUsecase) {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()

        let start = GoogleCalendar.EventOrigin.GoogleEventTime() |> \.date .~ startDate
        let end = GoogleCalendar.EventOrigin.GoogleEventTime() |> \.date .~ endDate
        let origin = GoogleCalendar.EventOrigin(id: "instance_id", summary: "origin name")
            |> \.start .~ start
            |> \.end .~ end

        let calendarUsecase = StubGoogleCalendarUsecase()
        calendarUsecase.stubDetail = origin

        let viewModel = GoogleCalendarEventEditViewModelImple(
            calendarId: "calendar_id", accountId: "account_id", eventId: "instance_id",
            googleCalendarUsecase: calendarUsecase,
            calendarSettingUsecase: settingUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return (viewModel, calendarUsecase)
    }
}


// MARK: - 원본 이벤트 로드

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func prepare_providesInitialValuesFromOrigin() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()

        // when
        let name = try await self.firstOutput(
            expectConfirm("이름 초기값"), for: viewModel.eventName
        ) { viewModel.prepare() }
        let time = try await self.firstOutput(expectConfirm("시간 초기값"), for: viewModel.selectedTime)
        let location = try await self.firstOutput(expectConfirm("장소 초기값"), for: viewModel.location)
        let memo = try await self.firstOutput(expectConfirm("메모 초기값"), for: viewModel.memo)
        let colorModel = try await self.firstOutput(expectConfirm("색상 초기값"), for: viewModel.selectedColorModel)

        // then
        #expect(name == "origin name")
        switch time {
        case .period:
            break
        default:
            Issue.record("기간 타입 시간이어야 함")
        }
        #expect(location == "origin location")
        #expect(memo == "origin memo")
        #expect(colorModel?.colorId == "3")
        #expect(colorModel?.calendarId == "calendar_id")
    }
}


// MARK: - 저장 파라미터 구성 — 변경분만 담기

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func save_withOnlyNameChanged_sendsOnlySummaryInParams() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        viewModel.enter(name: "new name")
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = usecase.didUpdateEventWith?.params
        #expect(params?.summary == "new name")
        #expect(params?.start == nil)
        #expect(params?.end == nil)
        #expect(params?.location == nil)
        #expect(params?.description == nil)
        #expect(params?.colorId == nil)
    }

    @Test func save_withOnlyTimeChanged_sendsOnlyStartAndEndInParams() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        viewModel.selectStartTime(Date(timeIntervalSince1970: 1_755_000_000))
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = usecase.didUpdateEventWith?.params
        #expect(params?.start != nil)
        #expect(params?.end != nil)
        #expect(params?.summary == nil)
        #expect(params?.location == nil)
        #expect(params?.description == nil)
        #expect(params?.colorId == nil)
    }
}


// MARK: - all-day 왕복 (B1 회귀 — 저장할 때마다 하루씩 늘어나던 버그)

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func save_singleDayAllDayEvent_touchingStartOnly_keepsOriginalEndDate() async throws {
        // given — 8/13 하루짜리(구글 raw: start=8/13, end=8/14 배타적)
        let (viewModel, usecase) = self.makeAllDayViewModel(startDate: "2026-08-13", endDate: "2026-08-14")
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when — 시작일 피커만 하루 당김. 종료일은 안 건드림
        let newStart = "2026-08-12".date(form: "yyyy-MM-dd", timeZoneAbbre: "KST")
        viewModel.selectStartTime(newStart)
        try await self.waitSaveCompleted { viewModel.save() }

        // then — end.date 는 원본 그대로(8/14), 저장마다 하루씩 늘어나지 않는다
        let params = usecase.didUpdateEventWith?.params
        #expect(params?.end?.date == "2026-08-14")
    }

    @Test func save_multiDayAllDayEvent_touchingStartOnly_keepsOriginalEndDate() async throws {
        // given — 8/13~8/15 사흘짜리(구글 raw: start=8/13, end=8/16 배타적)
        let (viewModel, usecase) = self.makeAllDayViewModel(startDate: "2026-08-13", endDate: "2026-08-16")
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        let newStart = "2026-08-12".date(form: "yyyy-MM-dd", timeZoneAbbre: "KST")
        viewModel.selectStartTime(newStart)
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = usecase.didUpdateEventWith?.params
        #expect(params?.end?.date == "2026-08-16")
    }
}


// MARK: - 장소·메모 비우기 — 빈 문자열로 실어야 구글이 필드를 지운다

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func save_whenLocationCleared_sendsEmptyStringInParams() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        viewModel.enter(location: "")
        try await self.waitSaveCompleted { viewModel.save() }

        // then — nil(안 건드림)이 아니라 빈 문자열로 실려야 PATCH 바디에서 키가 살아남는다
        let params = usecase.didUpdateEventWith?.params
        #expect(params?.location == "")
        #expect(params?.summary == nil)
        #expect(params?.description == nil)
    }

    @Test func save_whenMemoCleared_sendsEmptyStringInParams() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        viewModel.enter(memo: "")
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = usecase.didUpdateEventWith?.params
        #expect(params?.description == "")
        #expect(params?.summary == nil)
    }
}


// MARK: - 변경 없으면 저장 비활성

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func whenNothingChanged_isSavableIsFalse() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()

        // when
        let isSavable = try await self.firstOutput(
            expectConfirm("isSavable 확인"), for: viewModel.isSavable
        ) { viewModel.prepare() }

        // then
        #expect(isSavable == false)
    }
}


// MARK: - hasChanges — 스와이프 dismiss 보호가 참조하는 값 (isSavable과 별개 개념)

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func whenNothingChanged_hasChangesIsFalse() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()

        // when
        let hasChanges = try await self.firstOutput(
            expectConfirm("hasChanges 확인"), for: viewModel.hasChanges
        ) { viewModel.prepare() }

        // then
        #expect(hasChanges == false)
    }

    @Test func whenNameClearedToEmpty_hasChangesIsTrueButIsSavableIsFalse() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        viewModel.enter(name: "")
        let hasChanges = try await self.firstOutput(expectConfirm("hasChanges"), for: viewModel.hasChanges)
        let isSavable = try await self.firstOutput(expectConfirm("isSavable"), for: viewModel.isSavable)

        // then
        #expect(hasChanges == true)
        #expect(isSavable == false)
    }
}


// MARK: - 저장 성공 시 listener 통지 + 닫기

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func save_success_notifiesListenerAndCloses() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        viewModel.enter(name: "updated name")

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.spyRouter.didClosed == true)
        #expect(self.spyListener.didUpdateEvent != nil)
    }

    @Test func save_failure_keepsSceneOpenAndInputRetained() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        usecase.stubUpdatedEventOrigin = nil
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        viewModel.enter(name: "updated name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyRouter.didClosed == nil)
        #expect(self.spyRouter.didShowError != nil)
        let isSavingNow = try await self.firstOutput(expectConfirm("isSaving false"), for: viewModel.isSaving)
        #expect(isSavingNow == false)
        let nameStillEdited = try await self.firstOutput(expectConfirm("입력값 유지"), for: viewModel.eventName)
        #expect(nameStillEdited == "updated name")
    }
}


// MARK: - 반복 이벤트 저장 범위 선택

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func save_repeatingEvent_showsScopeActionSheet() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(recurringEventId: "series_id")
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()

        // then
        #expect(self.spyRouter.didShowActionSheetWith != nil)
    }

    @Test func save_repeatingEvent_onlyThisTime_usesInstanceEventId() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(recurringEventId: "series_id")
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        viewModel.enter(name: "new name")
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::onlyThisTime::button".localized()
            })
        }

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(usecase.didUpdateEventWith?.eventId == "instance_id")
    }

    @Test func save_repeatingEvent_all_usesRecurringEventId() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(recurringEventId: "series_id")
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        viewModel.enter(name: "new name")
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::all::button".localized()
            })
        }

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(usecase.didUpdateEventWith?.eventId == "series_id")
    }

    @Test func save_nonRepeatingEvent_savesWithoutActionSheet() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(recurringEventId: nil)
        usecase.stubUpdatedEventOrigin = usecase.stubDetail
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        viewModel.enter(name: "new name")

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.spyRouter.didShowActionSheetWith == nil)
        #expect(usecase.didUpdateEventWith?.eventId == "instance_id")
    }
}


// MARK: - 삭제

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func remove_confirmed_notifiesListenerAndCloses() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        try await confirmation("삭제 완료 대기") { confirm in
            self.spyRouter.didCloseCallback = { confirm.confirm() }
            viewModel.remove()
            try await Task.sleep(for: .milliseconds(50))
        }

        // then
        #expect(self.spyRouter.didShowActionSheetWith == nil)
        #expect(self.spyRouter.didShowConfirmWith != nil)
        #expect(usecase.didRemoveEventWith?.eventId == "instance_id")
        #expect(self.spyListener.didRemoveEventId == "instance_id")
        #expect(self.spyRouter.didClosed == true)
    }

    @Test func remove_repeatingEvent_showsScopeActionSheet() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }

        // when
        viewModel.remove()

        // then
        #expect(self.spyRouter.didShowConfirmWith == nil)
        #expect(self.spyRouter.didShowActionSheetWith != nil)
    }

    @Test func remove_repeatingEvent_onlyThisTime_usesInstanceEventId() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::onlyThisTime::button".localized()
            })
        }

        // when
        try await confirmation("삭제 완료 대기") { confirm in
            self.spyRouter.didCloseCallback = { confirm.confirm() }
            viewModel.remove()
            try await Task.sleep(for: .milliseconds(50))
        }

        // then
        #expect(usecase.didRemoveEventWith?.eventId == "instance_id")
        #expect(self.spyListener.didRemoveEventId == "instance_id")
    }

    @Test func remove_repeatingEvent_all_usesRecurringEventId() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(
            expectConfirm("prepare 완료"), for: viewModel.eventName
        ) { viewModel.prepare() }
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::all::button".localized()
            })
        }

        // when
        try await confirmation("삭제 완료 대기") { confirm in
            self.spyRouter.didCloseCallback = { confirm.confirm() }
            viewModel.remove()
            try await Task.sleep(for: .milliseconds(50))
        }

        // then
        #expect(usecase.didRemoveEventWith?.eventId == "series_id")
        #expect(self.spyListener.didRemoveEventId == "series_id")
    }
}


// MARK: - 구글 캘린더에서 수정 — 더보기 메뉴 액션

extension GoogleCalendarEventEditViewModelImpleTests {

    @Test func editOnGoogleCalendar_opensOriginHtmlLink() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()
        let _ = try await self.firstOutput(expectConfirm("원본 로드"), for: viewModel.eventName) {
            viewModel.prepare()
        }

        // when
        viewModel.editOnGoogleCalendar()

        // then
        #expect(
            self.spyRouter.didOpenSafariPath == "https://calendar.google.com/event?eid=instance_id"
        )
    }

    @Test func editOnGoogleCalendar_whenOriginHasNoHtmlLink_notOpensSafari() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(htmlLink: nil)
        let _ = try await self.firstOutput(expectConfirm("원본 로드"), for: viewModel.eventName) {
            viewModel.prepare()
        }

        // when
        viewModel.editOnGoogleCalendar()

        // then
        #expect(self.spyRouter.didOpenSafariPath == nil)
    }

    @Test func hasDetailLink_beforeOriginLoaded_isFalse() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()

        // when
        let hasLink = try await self.firstOutput(
            expectConfirm("로드 전 링크 여부"), for: viewModel.hasDetailLink
        )

        // then
        #expect(hasLink == false)
    }

    @Test func hasDetailLink_whenOriginLoaded_isTrue() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()
        let expect = expectConfirm("로드 후 링크 여부")
        expect.count = 2

        // when
        let hasLinks = try await self.outputs(expect, for: viewModel.hasDetailLink) {
            viewModel.prepare()
        }

        // then
        #expect(hasLinks == [false, true])
    }

    @Test func hasDetailLink_whenOriginLoadedWithoutHtmlLink_isFalse() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(htmlLink: nil)
        let _ = try await self.firstOutput(expectConfirm("원본 로드"), for: viewModel.eventName) {
            viewModel.prepare()
        }

        // when
        let hasLink = try await self.firstOutput(
            expectConfirm("링크 없는 원본"), for: viewModel.hasDetailLink
        )

        // then
        #expect(hasLink == false)
    }
}


// MARK: - Doubles

private final class SpyRouter: BaseSpyRouter, GoogleCalendarEventEditRouting, @unchecked Sendable { }

private final class SpyListener: GoogleCalendarEventEditSceneListener, @unchecked Sendable {

    var didUpdateEvent: GoogleCalendar.EventOrigin?
    func googleCalendarEvent(didUpdate event: GoogleCalendar.EventOrigin) {
        self.didUpdateEvent = event
    }

    var didRemoveEventId: String?
    func googleCalendarEvent(didRemove eventId: String) {
        self.didRemoveEventId = eventId
    }
}
