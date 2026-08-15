//
//  GoogleCalendarEventDetailViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 5/24/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
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


final class GoogleCalendarEventDetailViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter = SpyRouter()
    private let integrationUsecase = StubExternalCalendarIntegrationUsecase([])
    private var lastCalendarUsecase: PrivateStubGoogleCalendarUsecase!

    private func makeViewModel(
        recurrence: String? = nil,
        isCanceled: Bool = false,
        customAttendees: [GoogleCalendar.EventOrigin.Attendee]? = nil,
        writePermission: GoogleCalendar.EventWritePermission? = .writable,
        shouldFailReauthenticate: Bool = false,
        summaryPerCall: [String]? = nil,
        recurringEventId: String? = nil,
        htmlLink: String? = "link",
        description: String? = "그냥 텍스트<br><b>볼드</b><br>첨부파일도 있을거다잉<br>마크다운임?",
        updatedOrigin: GoogleCalendar.EventOrigin? = GoogleCalendarEventDetailViewModelImpleTests.defaultUpdatedOrigin(),
        updateEventDelayMilliseconds: UInt64 = 0,
        eventDetailFailsFromCallIndex: Int? = nil
    ) -> GoogleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()

        let calendarUsecase = PrivateStubGoogleCalendarUsecase()
        if let writePermission {
            calendarUsecase.stubWritePermission = writePermission
        } else {
            calendarUsecase.shouldEmitWritePermission = false
        }
        calendarUsecase.summaryPerCall = summaryPerCall
        calendarUsecase.additionalStubbing = { stub in
            stub
                |> \.attendees .~ (customAttendees ?? stub.attendees)
                |> \.recurrence .~ (recurrence.map { [$0] })
                |> \.status .~ (isCanceled ? .cancelled : .confirmed)
                |> \.recurringEventId .~ recurringEventId
                |> \.htmlLink .~ htmlLink
                |> \.description .~ description
        }
        calendarUsecase.stubUpdatedEventOrigin = updatedOrigin
        calendarUsecase.updateEventDelayMilliseconds = updateEventDelayMilliseconds
        calendarUsecase.eventDetailFailsFromCallIndex = eventDetailFailsFromCallIndex
        calendarUsecase.refreshGoogleCalendarEventTags()
        self.lastCalendarUsecase = calendarUsecase
        self.integrationUsecase.shouldFailReauthenticate = shouldFailReauthenticate

        let viewModel = GoogleCalendarEventDetailViewModelImple(
            calenadrId: "g:7", accountId: "stub@gmail.com", eventId: "id",
            googleCalendarUsecase: calendarUsecase,
            calendarSettingUsecase: settingUsecase,
            externalCalendarIntegrationUsecase: self.integrationUsecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase()
        )
        viewModel.router = self.spyRouter
        return viewModel
    }

    private static func defaultUpdatedOrigin() -> GoogleCalendar.EventOrigin {
        let start = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2026-08-13T10:00:00+09:00"
        let end = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2026-08-13T11:00:00+09:00"
        return GoogleCalendar.EventOrigin(id: "id", summary: "updated name")
            |> \.start .~ start
            |> \.end .~ end
            |> \.location .~ "updated location"
    }

    private func makeAllDayViewModel(
        startDate: String, endDate: String
    ) -> GoogleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()

        let start = GoogleCalendar.EventOrigin.GoogleEventTime() |> \.date .~ startDate
        let end = GoogleCalendar.EventOrigin.GoogleEventTime() |> \.date .~ endDate

        let calendarUsecase = PrivateStubGoogleCalendarUsecase()
        calendarUsecase.additionalStubbing = { stub in
            stub |> \.start .~ start |> \.end .~ end
        }
        calendarUsecase.stubUpdatedEventOrigin = GoogleCalendar.EventOrigin(id: "id", summary: "name")
            |> \.start .~ start
            |> \.end .~ end
        calendarUsecase.refreshGoogleCalendarEventTags()
        self.lastCalendarUsecase = calendarUsecase

        let viewModel = GoogleCalendarEventDetailViewModelImple(
            calenadrId: "g:7", accountId: "stub@gmail.com", eventId: "id",
            googleCalendarUsecase: calendarUsecase,
            calendarSettingUsecase: settingUsecase,
            externalCalendarIntegrationUsecase: self.integrationUsecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase()
        )
        viewModel.router = self.spyRouter
        return viewModel
    }

    private func waitSaveCompleted(_ action: () -> Void) async throws {
        action()
        try await Task.sleep(for: .milliseconds(50))
    }
}

extension GoogleCalendarEventDetailViewModelImpleTests {
    
    @Test func viewModel_provideEventColorModel() async throws {
        // given
        let expect = expectConfirm("이벤트 색상 정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let model = try await self.firstOutput(expect, for: viewModel.eventColorModel) {
            viewModel.refresh()
        }
        
        // then
        #expect(model?.colorId == "color_id")
        #expect(model?.calendarId == "g:7")
    }
    
    @Test func viewModel_provideEventName() async throws {
        // given
        let expect = expectConfirm("이벤트 이름정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let name = try await self.firstOutput(expect, for: viewModel.eventName) {
            viewModel.refresh()
        }
        
        // then
        #expect(name == "name")
    }
    
    @Test func viewModel_provideTimeText() async throws {
        // given
        let expect = expectConfirm("시간정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let time = try await self.firstOutput(expect, for: viewModel.timeText) {
            viewModel.refresh()
        }
        
        // then
        switch time {
        case .period(let st, let et):
            #expect(st.day == "May 24 (Sat)")
            #expect(et.day == "May 25 (Sun)")
        default:
            Issue.record("기대한 갑싱 아님")
        }
    }
    
    @Test func viewModel_provideDDayText() async throws {
        // given
        let expect = expectConfirm("d-day 정보 제공")
        expect.count = 3
        let viewModel = self.makeViewModel()
        
        // when
        let days = try await self.outputs(expect, for: viewModel.ddayText) {
            viewModel.refresh()
        }
        
        // then
        #expect(days == [
            "D+4", "D-Day", "D-4"
        ])
    }
    
    @Test func viewModel_provideCalendarModel() async throws {
        // given
        let expect = expectConfirm("캘린더 정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let model = try await self.firstOutput(expect, for: viewModel.calendarModel) {
            viewModel.refresh()
        } ?? nil
        
        // then
        #expect(model?.calenarId == "g:7")
        #expect(model?.name == "g:7")
    }
    
    @Test func viewModel_provideLocation() async throws {
        // given
        let expect = expectConfirm("장소정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let location = try await self.firstOutput(expect, for: viewModel.location) {
            viewModel.refresh()
        }
        
        // then
        #expect(location == "location")
    }
    
    private func expectRecurrenceText(_ recurrence: String?) -> String? {
        switch recurrence {
        case .none: return nil
        case "RRULE:FREQ=DAILY": return "Every day"
        case "RRULE:FREQ=DAILY;INTERVAL=5": return "Every 5 Days"
        case "RRULE:FREQ=WEEKLY;BYDAY=TU": return "Every Week TUE"
        case "RRULE:FREQ=WEEKLY;INTERVAL=3;BYDAY=TU": return "Every 3 Weeks TUE"
        case "RRULE:FREQ=MONTHLY;BYDAY=-1WE": return "Every Month Last WED"
        case "RRULE:FREQ=MONTHLY;INTERVAL=3;BYDAY=2WE": return "Every 3 Months 2nd WED"
        case "RRULE:FREQ=MONTHLY;INTERVAL=2": return "Every 2 Months"
        case "RRULE:FREQ=YEARLY": return "Every Year"
        case "RRULE:FREQ=YEARLY;INTERVAL=3": return "Every 3 Years"
        case "RRULE:FREQ=WEEKLY;BYDAY=FR,MO,TH,TU,WE": return "Every Week MON,TUE,WED,THU,FRI"
        case "RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20250816T145959Z;BYDAY=SA": return "Every Week SAT\nuntil Aug 16, 2025"
        case "RRULE:FREQ=DAILY;COUNT=3": return "Every day\n3 time(s)"
        default: return ""
        }
    }
    
    @Test(arguments: [
        nil,
        "RRULE:FREQ=DAILY",
        "RRULE:FREQ=DAILY;INTERVAL=5",
        "RRULE:FREQ=WEEKLY;BYDAY=TU",
        "RRULE:FREQ=WEEKLY;INTERVAL=3;BYDAY=TU",
        "RRULE:FREQ=MONTHLY;BYDAY=-1WE",
        "RRULE:FREQ=MONTHLY;INTERVAL=3;BYDAY=2WE",
        "RRULE:FREQ=MONTHLY;INTERVAL=2",
        "RRULE:FREQ=YEARLY",
        "RRULE:FREQ=YEARLY;INTERVAL=3",
        "RRULE:FREQ=WEEKLY;BYDAY=FR,MO,TH,TU,WE",
        "RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20250816T145959Z;BYDAY=SA",
        "RRULE:FREQ=DAILY;COUNT=3"
    ])
    func viewModel_provideRecurrenceText(_ recurrence: String?) async throws {
        // given
        let expect = self.expectConfirm("이벤트 반복 정보 제공")
        let viewModel = self.makeViewModel(recurrence: recurrence)
        
        // when
        let text = try await self.firstOutput(expect, for: viewModel.repeatOption) {
            viewModel.refresh()
        }
        
        // then
        let expectText = self.expectRecurrenceText(recurrence)
        let comment = Comment(stringLiteral: recurrence ?? "nil")
        #expect(text == expectText, comment)
    }
    
    @Test func viewModel_provideDescriptionModel() async throws {
        // given
        let expect = expectConfirm("이벤트 설명 모델 제공")
        let viewModel = self.makeViewModel()

        // when
        let model = try await self.firstOutput(expect, for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // then
        #expect(model == .richText("그냥 텍스트<br><b>볼드</b><br>첨부파일도 있을거다잉<br>마크다운임?"))
    }
    
    @Test func viewModel_provideAttachmentModels() async throws {
        // given
        let expect = expectConfirm("attachment model 정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let models = try await self.firstOutput(expect, for: viewModel.attachments) {
            viewModel.refresh()
        } ?? nil
        
        // then
        #expect(models?.count == 1)
        let first = models?.first
        #expect(first?.title == "file_title")
        #expect(first?.fileURL == "fileurl")
        #expect(first?.iconLink == "icon")
    }
    
    @Test func viewModel_provideAttendeeModels() async throws {
        // given
        let expect = expectConfirm("attendee 정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let list = try await self.firstOutput(expect, for: viewModel.attendees) {
            viewModel.refresh()
        } ?? nil
        
        // then
        #expect(list?.totalCounts == 33)
        let organizer = list?.attendees.first(where: { $0.isOrganizer })
        #expect(organizer?.id == "id:12")
        let ids = list?.attendees.map { $0.id }
        #expect(ids == [
            "id:12", "id:31", "id:0", "id:2", "id:4",
            "id:6", "id:8", "id:10", "id:14", "id:16"
        ])
        let isAccepts = list?.attendees.map { $0.isAccepted }
        #expect(isAccepts == [
            true, false, true, true, true,
            true, true, true, true, true
        ])
    }
    
    @Test func viewModel_provideAttendeeModelsWithEmailAndExcludeResource() async throws {
        // given
        let expect = expectConfirm("attendee 정보 제공 - id 없이 email만 있는 경우 + 리소스는 제외하고 제공")
        let viewModel = self.makeViewModel(customAttendees: [
            GoogleCalendar.EventOrigin.Attendee()
                |> \.email .~ "organizer@email.com" |> \.organizer .~ true,
            GoogleCalendar.EventOrigin.Attendee()
                |> \.email .~ "me@email.com" |> \.selfValue .~ true,
            GoogleCalendar.EventOrigin.Attendee()
                |> \.email .~ "meetingRoom" |> \.resource .~ true
        ])
        
        // when
        let list = try await self.firstOutput(expect, for: viewModel.attendees) {
            viewModel.refresh()
        } ?? nil
        
        // then
        #expect(list?.totalCounts == 2)
        let ids = list?.attendees.map { $0.id }
        #expect(ids == ["organizer@email.com", "me@email.com"])
        let organizer = list?.attendees.first(where:  { $0.isOrganizer })
        #expect(organizer?.isOrganizer == true)
        #expect(organizer?.id == "organizer@email.com")
        #expect(organizer?.name == "organizer@email.com")
        #expect(organizer?.isAccepted == false)
    }
    
    @Test func viewModel_provideConferenceData() async throws {
        // given
        let expect = expectConfirm("conference data 정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let model = try await self.firstOutput(expect, for: viewModel.conferenceModel) {
            viewModel.refresh()
        } ?? nil
        
        // then
        #expect(model?.name == "solution")
        #expect(model?.iconURL == "icon")
        #expect(model?.entries.count == 1)
        #expect(model?.entries.first?.uri == "some.com")
        #expect(model?.entries.first?.entryCodeKey == "eventDetail::gogoleEvent::conference::passCode".localized())
        #expect(model?.entries.first?.entryCodeValue == "pass code")
    }
}

// MARK: - refresh() 반복 호출과 구독 누적 방지 (포그라운드 재진입 등)

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func refresh_calledMultipleTimes_doesNotAccumulateEventWritePermissionSubscriptions() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when — 포그라운드 재진입처럼 refresh() 가 반복 호출됨
        viewModel.refresh()
        viewModel.refresh()
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(10))

        // then — internalBind() 시점에 1회만 구독한다. refresh() 는 새 구독을 만들지 않는다
        #expect(self.lastCalendarUsecase.didRequestEventWritePermissionWith.count == 1)
    }
}


// MARK: - editEvent(): 쓰기 권한별 분기

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func editEvent_whenWritable_routesToEditScene() {
        // given
        let viewModel = self.makeViewModel(writePermission: .writable)
        viewModel.refresh()

        // when
        viewModel.editEvent()

        // then
        #expect(self.spyRouter.didRouteToEditSceneWith?.calendarId == "g:7")
        #expect(self.spyRouter.didRouteToEditSceneWith?.accountId == "stub@gmail.com")
        #expect(self.spyRouter.didRouteToEditSceneWith?.eventId == "id")
        #expect(self.spyRouter.didShowConfirmWith == nil)
    }

    @Test func editEvent_whenNeedReauthentication_confirmed_reauthenticatesThenRoutesToEditScene() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .needReauthentication)
        self.spyRouter.shouldConfirmNotCancel = true
        viewModel.refresh()

        // when
        viewModel.editEvent()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowConfirmWith?.title == "eventDetail::gogoleEvent::reauthenticate::title".localized())
        #expect(self.integrationUsecase.didReauthenticateWith?.accountId == "stub@gmail.com")
        #expect(self.spyRouter.didRouteToEditSceneWith?.eventId == "id")
    }

    @Test func editEvent_whenNeedReauthentication_declined_doesNotRoute() {
        // given
        let viewModel = self.makeViewModel(writePermission: .needReauthentication)
        self.spyRouter.shouldConfirmNotCancel = false
        viewModel.refresh()

        // when
        viewModel.editEvent()

        // then
        #expect(self.integrationUsecase.didReauthenticateWith == nil)
        #expect(self.spyRouter.didRouteToEditSceneWith == nil)
    }

    @Test func editEvent_whenNeedReauthentication_andReauthenticateFails_showsErrorAndDoesNotRoute() async throws {
        // given
        let viewModel = self.makeViewModel(
            writePermission: .needReauthentication, shouldFailReauthenticate: true
        )
        self.spyRouter.shouldConfirmNotCancel = true
        viewModel.refresh()

        // when
        viewModel.editEvent()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowError != nil)
        #expect(self.spyRouter.didRouteToEditSceneWith == nil)
    }

    @Test func editEvent_whenNeedReauthentication_usesGoogleServiceFromUsecaseNotAHardcodedLiteral() async throws {
        // given — composition root 가 주입한 서비스 값(scopes 비움)을 usecase 가 들고 있다고 가정
        let viewModel = self.makeViewModel(writePermission: .needReauthentication)
        self.lastCalendarUsecase.googleService = GoogleCalendarService(scopes: [])
        self.spyRouter.shouldConfirmNotCancel = true
        viewModel.refresh()

        // when
        viewModel.editEvent()
        try await Task.sleep(for: .milliseconds(10))

        // then — ViewModel 이 GoogleCalendarService(scopes: [.readWrite]) 를 직접 새로 만들지 않고
        // usecase 가 들고 있던 값(빈 scopes)을 그대로 재인증에 전달한다
        let usedService = self.integrationUsecase.didReauthenticateWithService as? GoogleCalendarService
        #expect(usedService?.scopes == [])
    }

    @Test func editEvent_whenReadOnlyCalendar_doesNothing() {
        // given
        let viewModel = self.makeViewModel(writePermission: .readOnlyCalendar)
        viewModel.refresh()

        // when
        viewModel.editEvent()

        // then
        #expect(self.spyRouter.didRouteToEditSceneWith == nil)
        #expect(self.spyRouter.didShowConfirmWith == nil)
    }
}


// MARK: - isEditable / readOnlyCalendarMessage 노출 — 권한 3상태 전수 표

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test(
        "권한별 isEditable/readOnlyCalendarMessage 노출",
        arguments: [
            (GoogleCalendar.EventWritePermission.writable, true, false),
            (GoogleCalendar.EventWritePermission.needReauthentication, true, false),
            (GoogleCalendar.EventWritePermission.readOnlyCalendar, false, true)
        ]
    )
    func provideIsEditableAndReadOnlyMessage(
        _ permission: GoogleCalendar.EventWritePermission,
        _ expectedIsEditable: Bool,
        _ expectedHasReadOnlyMessage: Bool
    ) async throws {
        // given
        let comment = Comment(stringLiteral: "\(permission)")
        let viewModel = self.makeViewModel(writePermission: permission)

        // when
        let isEditable = try await self.firstOutput(
            expectConfirm("isEditable: \(permission)"), for: viewModel.isEditable
        ) {
            viewModel.refresh()
        }
        let message = try await self.firstOutput(
            expectConfirm("readOnlyCalendarMessage: \(permission)"), for: viewModel.readOnlyCalendarMessage
        ) ?? nil

        // then
        #expect(isEditable == expectedIsEditable, comment)
        let expectedMessage = expectedHasReadOnlyMessage
            ? "eventDetail::gogoleEvent::readOnlyCalendar::message".localized()
            : nil
        #expect(message == expectedMessage, comment)
    }
}


// MARK: - 편집 결과 반영 (GoogleCalendarEventEditSceneListener)

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func googleCalendarEvent_didUpdate_refreshesEventName() async throws {
        // given
        let expect = expectConfirm("수정된 이벤트 이름 반영")
        expect.count = 2
        let viewModel = self.makeViewModel()
        let updated = GoogleCalendar.EventOrigin(id: "id", summary: "updated name")

        // when
        let names = try await self.outputs(expect, for: viewModel.eventName) {
            viewModel.refresh()
            viewModel.googleCalendarEvent(didUpdate: updated)
        }

        // then
        #expect(names == ["name", "updated name"])
    }

    @Test func googleCalendarEvent_didUpdate_withSeriesMasterResponse_refetchesInsteadOfApplyingItDirectly() async throws {
        // given — "전체 일정" 저장 응답(시리즈 마스터: recurringEventId 없음 + recurrence 있음)이 온다
        let viewModel = self.makeViewModel()
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(10))
        var seriesMaster = GoogleCalendar.EventOrigin(id: "series1", summary: "series master title")
        seriesMaster.recurrence = ["RRULE:FREQ=DAILY;COUNT=3"]

        // when
        viewModel.googleCalendarEvent(didUpdate: seriesMaster)
        try await Task.sleep(for: .milliseconds(10))

        // then — 마스터를 그대로 반영했다면 location 이 nil(마스터엔 없음)로 덮였을 것이다.
        // 대신 인스턴스를 재조회해 stub 의 원래 location("location")이 유지돼야 한다.
        let expect = expectConfirm("재조회 후 인스턴스 데이터 유지")
        let location = try await self.firstOutput(expect, for: viewModel.location)
        #expect(location == "location")
    }

    @Test func googleCalendarEvent_didRemove_closesDetailScene() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.googleCalendarEvent(didRemove: "id")

        // then
        #expect(self.spyRouter.didClosed == true)
    }
}

// MARK: - 구글 캘린더에서 보기 (점점점 메뉴)

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func hasDetailLink_reflectsHtmlLinkPresence() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let has = try await self.firstOutput(
            expectConfirm("hasDetailLink"), for: viewModel.hasDetailLink
        ) { viewModel.refresh() }

        // then — stub eventDetail 은 항상 htmlLink 를 가진다
        #expect(has == true)
    }

    @Test func hasDetailLink_whenOriginHasNoHtmlLink_isFalse() async throws {
        // given
        let viewModel = self.makeViewModel(htmlLink: nil)

        // when
        let has = try await self.firstOutput(
            expectConfirm("hasDetailLink"), for: viewModel.hasDetailLink
        ) { viewModel.refresh() }

        // then
        #expect(has == false)
    }

    @Test func viewOnGoogleCalendar_opensHtmlLinkInSafari() async throws {
        // given
        let viewModel = self.makeViewModel()
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(10))

        // when
        viewModel.viewOnGoogleCalendar()

        // then — routeToEditEvent(편집) 가 아니라 openSafari 로 연다
        #expect(self.spyRouter.didOpenSafariPath == "link")
        #expect(self.spyRouter.didRouteToEditSceneWith == nil)
    }
}

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func viewModel_selectURL() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.refresh()
        
        // when
        viewModel.selectLink(URL(string: "https://www.google.com")!)
        
        // then
        #expect(self.spyRouter.didOpenSafariPath == "https://www.google.com")
    }
    
    @Test func viewModel_selectAttachment() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.refresh()
        
        // when
        let attach = AttachmentModel(id: "some", fileURL: "url", title: "title")
        viewModel.selectAttachment(attach)
        
        // then
        #expect(self.spyRouter.didOpenSafariPath == "url")
    }
    
    @Test func viewModel_whenRefreshAndCanceled_showToastAndClose() async throws {
        // given
        let viewModel = self.makeViewModel(isCanceled: true)
        
        // when
        try await confirmation("취소된 이벤트의 경우 취소되었음을 알림") { confirm in
            self.spyRouter.didCloseCallback = {
                confirm.confirm()
            }
            
            viewModel.refresh()
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // then
        #expect(self.spyRouter.didShowToastWithMessage == "eventDetail::gogoleEvent::canceled::message".localized())
        
    }
}

// MARK: - 편집 입력 상태

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func enterName_updatesEventNamePublisher() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 이름 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "new name")
        let updated = try await self.firstOutput(expectConfirm("변경된 이름"), for: viewModel.eventName)

        // then
        #expect(updated == "new name")
    }

    @Test func selectStartTime_updatesTimeTextPublisher() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 시간 로드"), for: viewModel.timeText) {
            viewModel.refresh()
        }
        let timeZone = TimeZone(abbreviation: "KST")!
        let newStart = Date(timeIntervalSince1970: 1_748_400_000)

        // when
        viewModel.selectStartTime(newStart)
        let updated = try await self.firstOutput(expectConfirm("변경된 시간"), for: viewModel.timeText)

        // then
        let expectedDay = SelectTimeText(newStart.timeIntervalSince1970, timeZone).day
        switch updated {
        case .period(let start, _):
            #expect(start.day == expectedDay)
        default:
            Issue.record("기간 타입 시간이어야 함")
        }
    }

    @Test func toggleAllDay_switchesTimeToAllDay() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 시간 로드"), for: viewModel.timeText) {
            viewModel.refresh()
        }

        // when
        viewModel.toggleAllDay()
        let updated = try await self.firstOutput(expectConfirm("종일 전환 시간"), for: viewModel.timeText) ?? nil

        // then
        #expect(updated?.isAllDay == true)
    }

    @Test func enterLocation_updatesLocationPublisher() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 장소 로드"), for: viewModel.location) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(location: "new location")
        let updated = try await self.firstOutput(expectConfirm("변경된 장소"), for: viewModel.location)

        // then
        #expect(updated == "new location")
    }

    @Test func selectColorId_updatesEventColorModelPublisher() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 색상 로드"), for: viewModel.eventColorModel) {
            viewModel.refresh()
        }

        // when
        viewModel.select(colorId: "new_color")
        let updated = try await self.firstOutput(expectConfirm("변경된 색상"), for: viewModel.eventColorModel)

        // then
        #expect(updated?.colorId == "new_color")
        #expect(updated?.calendarId == "g:7")
    }

    @Test func ddayText_followsEditedTimeNotOrigin() async throws {
        // given — countDays 스텁은 입력값과 무관하게 항상 [-4, 0, 4]를 방출하므로,
        // 시간 편집 후 재구독(스트림 재발행) 여부로 소스 전환을 판별한다.
        let expect = expectConfirm("edited time 기준으로 d-day 재계산")
        expect.count = 6
        let viewModel = self.makeViewModel()

        // when
        let days = try await self.outputs(expect, for: viewModel.ddayText) {
            viewModel.refresh()
            viewModel.selectStartTime(Date(timeIntervalSince1970: 1_748_400_000))
        }

        // then
        #expect(days == ["D+4", "D-Day", "D-4", "D+4", "D-Day", "D-4"])
    }

    @Test func whenNothingChanged_isSavableIsFalse() async throws {
        // given
        let viewModel = self.makeViewModel()

        // when
        let isSavable = try await self.firstOutput(expectConfirm("isSavable 확인"), for: viewModel.isSavable) {
            viewModel.refresh()
        }

        // then
        #expect(isSavable == false)
    }

    @Test func whenNameClearedToEmpty_hasChangesIsTrueButIsSavableIsFalse() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "")
        let hasChanges = try await self.firstOutput(expectConfirm("hasChanges"), for: viewModel.hasChanges)
        let isSavable = try await self.firstOutput(expectConfirm("isSavable"), for: viewModel.isSavable)

        // then
        #expect(hasChanges == true)
        #expect(isSavable == false)
    }

    @Test func refresh_whenHasUnsavedChanges_doesNotDiscardThem() async throws {
        // given
        let viewModel = self.makeViewModel()
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

    @Test func refresh_whenNoChanges_appliesLatestOrigin() async throws {
        // given
        let viewModel = self.makeViewModel(summaryPerCall: ["name", "updated name"])
        _ = try await self.firstOutput(expectConfirm("최초 origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when — 편집 없이 다시 refresh
        viewModel.refresh()
        let name = try await self.firstOutput(expectConfirm("최신 origin 반영"), for: viewModel.eventName)

        // then
        #expect(name == "updated name")
    }
}

// MARK: - 읽기 전용 캘린더에서는 편집 입력이 무시된다

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func enterName_whenReadOnlyCalendar_doesNotMarkAsChanged() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .readOnlyCalendar)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "changed")

        // then
        let hasChanges = try await self.firstOutput(expectConfirm("hasChanges"), for: viewModel.hasChanges)
        let name = try await self.firstOutput(expectConfirm("eventName"), for: viewModel.eventName)
        #expect(hasChanges == false)
        #expect(name == "name")
    }

    @Test func selectColorId_whenReadOnlyCalendar_doesNotMarkAsChanged() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .readOnlyCalendar)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventColorModel) {
            viewModel.refresh()
        }

        // when
        viewModel.select(colorId: "new_color")

        // then
        let hasChanges = try await self.firstOutput(expectConfirm("hasChanges"), for: viewModel.hasChanges)
        #expect(hasChanges == false)
    }

    @Test func enterName_whenWritePermissionNotLoadedYet_appliesChange() async throws {
        // given — eventWritePermission 이 아직 방출하지 않은 상태(권한 조회 전)
        let viewModel = self.makeViewModel(writePermission: nil)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "changed")

        // then
        let updated = try await self.firstOutput(expectConfirm("변경된 이름"), for: viewModel.eventName)
        #expect(updated == "changed")
    }
}


// MARK: - 저장 — 쓰기 권한 게이팅

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func save_whenWritable_sendsOnlyChangedFieldsInParams() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .writable)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(name: "new name")
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = self.lastCalendarUsecase.didUpdateEventWith?.params
        #expect(params?.summary == "new name")
        #expect(params?.start == nil)
        #expect(params?.end == nil)
        #expect(params?.location == nil)
        #expect(params?.description == nil)
        #expect(params?.colorId == nil)
    }

    @Test func save_whenNeedReauthentication_confirmed_reauthenticatesThenSaves() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .needReauthentication)
        self.spyRouter.shouldConfirmNotCancel = true
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.integrationUsecase.didReauthenticateWith?.accountId == "stub@gmail.com")
        #expect(self.lastCalendarUsecase.didUpdateEventWith?.params.summary == "new name")
    }

    @Test func save_whenNeedReauthentication_declined_doesNotSave() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .needReauthentication)
        self.spyRouter.shouldConfirmNotCancel = false
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.integrationUsecase.didReauthenticateWith == nil)
        #expect(self.lastCalendarUsecase.didUpdateEventWith == nil)
        let name = try await self.firstOutput(expectConfirm("입력값 유지"), for: viewModel.eventName)
        #expect(name == "new name")
    }

    @Test func save_whenNeedReauthentication_andReauthenticateFails_showsErrorAndDoesNotSave() async throws {
        // given
        let viewModel = self.makeViewModel(
            writePermission: .needReauthentication, shouldFailReauthenticate: true
        )
        self.spyRouter.shouldConfirmNotCancel = true
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.spyRouter.didShowError != nil)
        #expect(self.lastCalendarUsecase.didUpdateEventWith == nil)
    }

    @Test func save_whenReadOnlyCalendar_inputIsIgnoredSoNoUpdateRequested() async throws {
        // given — enter(name:) 가 updateCurrentFields 의 읽기 전용 가드에서 이미 무시된다.
        // runWithWritePermission 의 readOnlyCalendar 게이트 자체는 remove_whenReadOnlyCalendar_doesNothing 이 덮는다.
        let viewModel = self.makeViewModel(writePermission: .readOnlyCalendar)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastCalendarUsecase.didUpdateEventWith == nil)
        #expect(self.spyRouter.didShowConfirmWith == nil)
        #expect(self.spyRouter.didClosed == nil)
    }
}


// MARK: - 저장 파라미터 구성

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func save_whenLocationCleared_sendsEmptyStringInParams() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when — nil(안 건드림)이 아니라 빈 문자열로 실어야 구글이 필드를 지운다
        viewModel.enter(location: "")
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = self.lastCalendarUsecase.didUpdateEventWith?.params
        #expect(params?.location == "")
        #expect(params?.summary == nil)
        #expect(params?.description == nil)
    }

    @Test func save_whenMemoCleared_sendsEmptyStringInParams() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(memo: "")
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = self.lastCalendarUsecase.didUpdateEventWith?.params
        #expect(params?.description == "")
        #expect(params?.summary == nil)
    }

    @Test func save_singleDayAllDayEvent_touchingStartOnly_keepsOriginalEndDate() async throws {
        // given — 8/13 하루짜리(구글 raw: start=8/13, end=8/14 배타적)
        let viewModel = self.makeAllDayViewModel(startDate: "2026-08-13", endDate: "2026-08-14")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when — 시작일 피커만 하루 당김. 종료일은 안 건드림
        let newStart = "2026-08-12".date(form: "yyyy-MM-dd", timeZoneAbbre: "KST")
        viewModel.selectStartTime(newStart)
        try await self.waitSaveCompleted { viewModel.save() }

        // then — end.date 는 원본 그대로(8/14), 저장마다 하루씩 늘어나지 않는다
        let params = self.lastCalendarUsecase.didUpdateEventWith?.params
        #expect(params?.end?.date == "2026-08-14")
    }

    @Test func save_multiDayAllDayEvent_touchingStartOnly_keepsOriginalEndDate() async throws {
        // given — 8/13~8/15 사흘짜리(구글 raw: start=8/13, end=8/16 배타적)
        let viewModel = self.makeAllDayViewModel(startDate: "2026-08-13", endDate: "2026-08-16")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        let newStart = "2026-08-12".date(form: "yyyy-MM-dd", timeZoneAbbre: "KST")
        viewModel.selectStartTime(newStart)
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        let params = self.lastCalendarUsecase.didUpdateEventWith?.params
        #expect(params?.end?.date == "2026-08-16")
    }

    @Test func save_whenOnlyTimeRangeBecameInvalid_doesNotRequestUpdate() async throws {
        // given
        let viewModel = self.makeViewModel()
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when — 새 시작시각이 기존 종료시각보다 늦어 무효한 시간 범위가 된다.
        // asGoogleEventTimePair 가 nil 을 반환해 params 가 완전히 비고, save() 는 조기 반환한다
        let invalidStart = Date(timeIntervalSince1970: 1_900_000_000)
        viewModel.selectStartTime(invalidStart)
        try await self.waitSaveCompleted { viewModel.save() }

        // then — 업데이트 요청 자체가 안 나가고, 편집 화면과 달리 상세 화면도 닫히지 않는다
        #expect(self.lastCalendarUsecase.didUpdateEventWith == nil)
        #expect(self.spyRouter.didClosed == nil)
    }
}


// MARK: - 반복 이벤트 저장 범위

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func save_repeatingEvent_showsScopeActionSheet() async throws {
        // given
        let viewModel = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowActionSheetWith != nil)
    }

    @Test func save_repeatingEvent_onlyThisTime_usesInstanceEventId() async throws {
        // given
        let viewModel = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::onlyThisTime::button".localized()
            })
        }

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.lastCalendarUsecase.didUpdateEventWith?.eventId == "id")
    }

    @Test func save_repeatingEvent_all_usesRecurringEventId() async throws {
        // given
        let viewModel = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::all::button".localized()
            })
        }

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.lastCalendarUsecase.didUpdateEventWith?.eventId == "series_id")
    }
}


// MARK: - 저장 성공/실패

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func save_success_showsToastAndClosesScene() async throws {
        // given
        let updated = GoogleCalendar.EventOrigin(id: "id", summary: "saved name")
        let viewModel = self.makeViewModel(updatedOrigin: updated)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "new name")

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.spyRouter.didShowToastWithMessage == "eventDetail::gogoleEvent::saved::message".localized())
        #expect(self.spyRouter.didClosed == true)
    }

    @Test func save_failure_keepsSceneOpenAndInputRetained() async throws {
        // given
        let viewModel = self.makeViewModel(updatedOrigin: nil)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "updated name")

        // when
        try await self.waitSaveCompleted { viewModel.save() }

        // then
        #expect(self.spyRouter.didClosed == nil)
        #expect(self.spyRouter.didShowError != nil)
        let isSavingNow = try await self.firstOutput(expectConfirm("isSaving false"), for: viewModel.isSaving)
        #expect(isSavingNow == false)
        let nameStillEdited = try await self.firstOutput(expectConfirm("입력값 유지"), for: viewModel.eventName)
        #expect(nameStillEdited == "updated name")
    }
}


// MARK: - 저장 중 입력 무시

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func enterName_whileSaving_isIgnored() async throws {
        // given
        let viewModel = self.makeViewModel(updateEventDelayMilliseconds: 100)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        viewModel.enter(name: "before save")
        _ = try await self.firstOutput(expectConfirm("저장 전 입력 반영"), for: viewModel.eventName)

        // when — 저장 시작 직후(응답 오기 전)에 입력
        viewModel.save()
        try await Task.sleep(for: .milliseconds(10))
        viewModel.enter(name: "typed while saving")

        // then
        let name = try await self.firstOutput(expectConfirm("저장 중 입력 무시"), for: viewModel.eventName)
        #expect(name == "before save")
    }
}


// MARK: - 삭제

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func remove_whenWritable_confirmed_closesScene() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .writable)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastCalendarUsecase.didRemoveEventWith?.eventId == "id")
        #expect(self.spyRouter.didClosed == true)
    }

    @Test func remove_whenNeedReauthentication_confirmed_reauthenticatesThenRemoves() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .needReauthentication)
        self.spyRouter.shouldConfirmNotCancel = true
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.integrationUsecase.didReauthenticateWith?.accountId == "stub@gmail.com")
        #expect(self.lastCalendarUsecase.didRemoveEventWith?.eventId == "id")
        #expect(self.spyRouter.didClosed == true)
    }

    @Test func remove_whenReadOnlyCalendar_doesNothing() async throws {
        // given
        let viewModel = self.makeViewModel(writePermission: .readOnlyCalendar)
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastCalendarUsecase.didRemoveEventWith == nil)
        #expect(self.spyRouter.didShowConfirmWith == nil)
        #expect(self.spyRouter.didClosed == nil)
    }

    @Test func remove_repeatingEvent_showsScopeActionSheet() async throws {
        // given
        let viewModel = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.spyRouter.didShowConfirmWith == nil)
        #expect(self.spyRouter.didShowActionSheetWith != nil)
    }

    @Test func remove_repeatingEvent_onlyThisTime_usesInstanceEventId() async throws {
        // given
        let viewModel = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::onlyThisTime::button".localized()
            })
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastCalendarUsecase.didRemoveEventWith?.eventId == "id")
    }

    @Test func remove_repeatingEvent_all_usesRecurringEventId() async throws {
        // given
        let viewModel = self.makeViewModel(recurringEventId: "series_id")
        _ = try await self.firstOutput(expectConfirm("origin 로드"), for: viewModel.eventName) {
            viewModel.refresh()
        }
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: {
                $0.text == "eventDetail::gogoleEvent::repeating::all::button".localized()
            })
        }

        // when
        viewModel.remove()
        try await Task.sleep(for: .milliseconds(10))

        // then
        #expect(self.lastCalendarUsecase.didRemoveEventWith?.eventId == "series_id")
    }
}


// MARK: - 수정 불가 항목 안내

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func selectNotEditableField_showsGuideToast() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.selectNotEditableField()

        // then
        #expect(self.spyRouter.didShowToastWithMessage == "eventDetail::gogoleEvent::notEditableField::message".localized())
    }
}


// MARK: - 설명 서식 처리

extension GoogleCalendarEventDetailViewModelImpleTests {

    @Test func descriptionModel_whenOriginHasHTMLTag_isRichText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "그냥 텍스트<br><b>볼드</b>")

        // when
        let model = try await self.firstOutput(expectConfirm("설명 모델"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // then
        #expect(model == .richText("그냥 텍스트<br><b>볼드</b>"))
    }

    @Test func descriptionModel_whenOriginIsPlainText_isPlainText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "그냥 텍스트")

        // when
        let model = try await self.firstOutput(expectConfirm("설명 모델"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // then
        #expect(model == .plainText("그냥 텍스트"))
    }

    @Test func descriptionModel_whenPlainTextContainsAngleBracketedEmail_isPlainText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "연락처: <user@example.com> 입니다")

        // when
        let model = try await self.firstOutput(expectConfirm("설명 모델"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // then
        #expect(model == .plainText("연락처: <user@example.com> 입니다"))
    }

    @Test func descriptionModel_whenPlainTextContainsAngleBracketedURL_isPlainText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "<https://example.com>")

        // when
        let model = try await self.firstOutput(expectConfirm("설명 모델"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // then
        #expect(model == .plainText("<https://example.com>"))
    }

    @Test func descriptionModel_whenUppercaseHTMLTag_isRichText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "줄바꿈<BR>다음줄")

        // when
        let model = try await self.firstOutput(expectConfirm("설명 모델"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // then
        #expect(model == .richText("줄바꿈<BR>다음줄"))
    }

    @Test func descriptionModel_whenUnknownTagOnly_isPlainText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "<blockquote>인용</blockquote>")

        // when
        let model = try await self.firstOutput(expectConfirm("설명 모델"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // then
        #expect(model == .plainText("<blockquote>인용</blockquote>"))
    }

    @Test func startEditDescription_whenRichText_showsFormatLossConfirm() async throws {
        // given
        let viewModel = self.makeViewModel(description: "그냥 텍스트<br><b>볼드</b>")
        self.spyRouter.shouldConfirmNotCancel = false
        _ = try await self.firstOutput(expectConfirm("설명 로드"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // when
        viewModel.startEditDescription()

        // then
        #expect(self.spyRouter.didShowConfirmWith?.title == "common.info".localized())
        #expect(self.spyRouter.didShowConfirmWith?.message == "eventDetail::gogoleEvent::description::formatLoss::message".localized())
    }

    @Test func startEditDescription_confirmed_switchesToPlainText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "그냥 텍스트<br><b>볼드</b>")
        self.spyRouter.shouldConfirmNotCancel = true
        _ = try await self.firstOutput(expectConfirm("설명 로드"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // when
        viewModel.startEditDescription()
        let model = try await self.firstOutput(expectConfirm("전환된 설명 모델"), for: viewModel.descriptionModel)

        // then
        #expect(model == .plainText("그냥 텍스트<br><b>볼드</b>"))
    }

    @Test func startEditDescription_declined_staysRichText() async throws {
        // given
        let viewModel = self.makeViewModel(description: "그냥 텍스트<br><b>볼드</b>")
        self.spyRouter.shouldConfirmNotCancel = false
        _ = try await self.firstOutput(expectConfirm("설명 로드"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // when
        viewModel.startEditDescription()
        try await Task.sleep(for: .milliseconds(10))
        let model = try await self.firstOutput(expectConfirm("변화 없는 설명 모델"), for: viewModel.descriptionModel)

        // then
        #expect(model == .richText("그냥 텍스트<br><b>볼드</b>"))
    }

    @Test func startEditDescription_whenAlreadyPlainText_doesNotShowConfirm() async throws {
        // given
        let viewModel = self.makeViewModel(description: "그냥 텍스트")
        _ = try await self.firstOutput(expectConfirm("설명 로드"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // when
        viewModel.startEditDescription()

        // then
        #expect(self.spyRouter.didShowConfirmWith == nil)
    }

    @Test func startEditDescription_whenReadOnlyCalendar_doesNotShowConfirm() async throws {
        // given
        let viewModel = self.makeViewModel(
            writePermission: .readOnlyCalendar, description: "그냥 텍스트<br><b>볼드</b>"
        )
        _ = try await self.firstOutput(expectConfirm("설명 로드"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // when
        viewModel.startEditDescription()

        // then
        #expect(self.spyRouter.didShowConfirmWith == nil)
        let model = try await self.firstOutput(expectConfirm("서식 유지"), for: viewModel.descriptionModel)
        #expect(model == .richText("그냥 텍스트<br><b>볼드</b>"))
    }

    @Test func descriptionModel_whenPlainDescriptionEditedIntoTagText_staysPlainText() async throws {
        // given — 평문으로 로드된 설명은 편집 중 태그 패턴이 섞여도 판정이 뒤바뀌지 않는다
        let viewModel = self.makeViewModel(description: "그냥 텍스트")
        _ = try await self.firstOutput(expectConfirm("설명 로드"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }

        // when
        viewModel.enter(memo: "<b>볼드</b>")
        let model = try await self.firstOutput(expectConfirm("태그 입력 후 평문 유지"), for: viewModel.descriptionModel)

        // then
        #expect(model == .plainText("<b>볼드</b>"))
    }

    @Test func descriptionModel_afterConfirmedPlainEditing_staysPlainTextWhileTagsRemain() async throws {
        // given
        let viewModel = self.makeViewModel(description: "그냥 텍스트<br><b>볼드</b>")
        self.spyRouter.shouldConfirmNotCancel = true
        _ = try await self.firstOutput(expectConfirm("설명 로드"), for: viewModel.descriptionModel) {
            viewModel.refresh()
        }
        viewModel.startEditDescription()
        _ = try await self.firstOutput(expectConfirm("평문 전환 확인"), for: viewModel.descriptionModel)

        // when — 태그가 그대로 남은 채로 다른 값을 입력해도 다시 richText 로 안 바뀐다
        viewModel.enter(memo: "그냥 텍스트<br><b>볼드</b> 추가")
        let model = try await self.firstOutput(expectConfirm("평문 유지"), for: viewModel.descriptionModel)

        // then
        #expect(model == .plainText("그냥 텍스트<br><b>볼드</b> 추가"))
    }

}


private final class PrivateStubGoogleCalendarUsecase: StubGoogleCalendarUsecase, @unchecked Sendable {

    var additionalStubbing: ((GoogleCalendar.EventOrigin) -> GoogleCalendar.EventOrigin)?
    var summaryPerCall: [String]?
    private var eventDetailCallCount = 0
    var eventDetailFailsFromCallIndex: Int?
    var updateEventDelayMilliseconds: UInt64 = 0

    var didRequestEventWritePermissionWith: [(accountId: String, calendarId: String)] = []
    var shouldEmitWritePermission: Bool = true
    override func eventWritePermission(
        accountId: String, calendarId: String
    ) -> AnyPublisher<GoogleCalendar.EventWritePermission, Never> {
        self.didRequestEventWritePermissionWith.append((accountId, calendarId))
        guard self.shouldEmitWritePermission else { return Empty().eraseToAnyPublisher() }
        return super.eventWritePermission(accountId: accountId, calendarId: calendarId)
    }

    override func eventDetail(
        _ calendarId: String, _ eventId: String, accountId: String, at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
        let callIndex = self.eventDetailCallCount
        self.eventDetailCallCount += 1
        if let failsFrom = self.eventDetailFailsFromCallIndex, callIndex >= failsFrom {
            return Fail(error: RuntimeError("stub eventDetail failure")).eraseToAnyPublisher()
        }
        let summary = self.summaryPerCall?[safe: callIndex] ?? self.summaryPerCall?.last ?? "name"

        let start = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2025-05-24T12:00:00+09:00"
        let end = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2025-05-25T12:00:00+09:00"
        let attachment = GoogleCalendar.EventOrigin.Attachment()
            |> \.fileId .~ "id"
            |> \.fileUrl .~ "fileurl"
            |> \.title .~ "file_title"
            |> \.iconLink .~ "icon"
        let attendees = (0..<33).map { int -> GoogleCalendar.EventOrigin.Attendee in
            let attendee = GoogleCalendar.EventOrigin.Attendee()
                |> \.id .~ "id:\(int)"
                |> \.displayName .~ "name:\(int)"
                |> \.organizer .~ (int == 12)
                |> \.selfValue .~ (int == 31)
                |> \.responseStatus .~ (int % 2 == 0 ? "accepted" : "needsAction")
            return attendee
        }
        let entries = (0..<1).map { int -> GoogleCalendar.EventOrigin.ConferenceData.EntryPoint in
            return GoogleCalendar.EventOrigin.ConferenceData.EntryPoint()
                |> \.uri .~ "some.com"
                |> \.passcode .~ "pass code"
        }
        let solution = GoogleCalendar.EventOrigin.ConferenceData.Solution()
            |> \.iconUri .~ "icon"
            |> \.name .~ "solution"
        let data = GoogleCalendar.EventOrigin.ConferenceData()
            |> \.conferenceId .~ "id"
            |> \.conferenceSolution .~ solution
            |> \.entryPoints .~ entries
        let origin = GoogleCalendar.EventOrigin(id: eventId, summary: summary)
            |> \.start .~ start
            |> \.end .~ end
            |> \.location .~ "location"
            |> \.htmlLink .~ "link"
            |> \.description .~ "그냥 텍스트<br><b>볼드</b><br>첨부파일도 있을거다잉<br>마크다운임?"
            |> \.attachments .~ [attachment]
            |> \.attendees .~ attendees
            |> \.conferenceData .~ data
            |> \.colorId .~ "color_id"
        
        let stub = additionalStubbing?(origin) ?? origin

        return Just(stub).mapAsAnyError().eraseToAnyPublisher()
    }

    override func updateEvent(
        _ calendarId: String,
        _ eventId: String,
        accountId: String,
        at timeZone: TimeZone,
        params: GoogleCalendar.EventEditParams
    ) async throws -> GoogleCalendar.EventOrigin {
        if self.updateEventDelayMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(self.updateEventDelayMilliseconds))
        }
        return try await super.updateEvent(
            calendarId, eventId, accountId: accountId, at: timeZone, params: params
        )
    }
}

private final class SpyRouter: BaseSpyRouter, GoogleCalendarEventDetailRouting, @unchecked Sendable {

    var didRouteToEditSceneWith: (calendarId: String, accountId: String, eventId: String, listener: (any GoogleCalendarEventEditSceneListener)?)?
    func routeToEditEvent(
        calendarId: String, accountId: String, eventId: String,
        listener: (any GoogleCalendarEventEditSceneListener)?
    ) {
        self.didRouteToEditSceneWith = (calendarId, accountId, eventId, listener)
    }
}
