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
        writePermission: GoogleCalendar.EventWritePermission = .writable,
        shouldFailReauthenticate: Bool = false
    ) -> GoogleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()

        let calendarUsecase = PrivateStubGoogleCalendarUsecase()
        calendarUsecase.stubWritePermission = writePermission
        calendarUsecase.additionalStubbing = { stub in
            stub
                |> \.attendees .~ (customAttendees ?? stub.attendees)
                |> \.recurrence .~ (recurrence.map { [$0] })
                |> \.status .~ (isCanceled ? .cancelled : .confirmed)
        }
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
    
    @Test func viewModel_provideDescriptionHTMLText() async throws {
        // given
        let expect = expectConfirm("이벤트 설명 html text 정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let text = try await self.firstOutput(expect, for: viewModel.descriptionHTMLText) {
            viewModel.refresh()
        }
        
        // then
        #expect(text == "그냥 텍스트<br><b>볼드</b><br>첨부파일도 있을거다잉<br>마크다운임?")
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

private final class PrivateStubGoogleCalendarUsecase: StubGoogleCalendarUsecase, @unchecked Sendable {

    var additionalStubbing: ((GoogleCalendar.EventOrigin) -> GoogleCalendar.EventOrigin)?

    var didRequestEventWritePermissionWith: [(accountId: String, calendarId: String)] = []
    override func eventWritePermission(
        accountId: String, calendarId: String
    ) -> AnyPublisher<GoogleCalendar.EventWritePermission, Never> {
        self.didRequestEventWritePermissionWith.append((accountId, calendarId))
        return super.eventWritePermission(accountId: accountId, calendarId: calendarId)
    }

    override func eventDetail(
        _ calendarId: String, _ eventId: String, accountId: String, at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
     
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
        let origin = GoogleCalendar.EventOrigin(id: eventId, summary: "name")
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
