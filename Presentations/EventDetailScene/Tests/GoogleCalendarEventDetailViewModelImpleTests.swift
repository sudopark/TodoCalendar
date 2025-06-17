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
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


final class GoogleCalendarEventDetailViewModelImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter = SpyRouter()
    
    private func makeViewModel(
        recurrence: String? = nil
    ) -> GoogleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let calendarUsecase = PrivateStubGoogleCalendarUsecase()
        calendarUsecase.additionalStubbing = { stub in
            stub |> \.recurrence .~ (recurrence.map { [$0] })
        }
        calendarUsecase.refreshGoogleCalendarEventTags()
        
        let viewModel = GoogleCalendarEventDetailViewModelImple(
            calenadrId: "g:7", eventId: "id",
            googleCalendarUsecase: calendarUsecase,
            calendarSettingUsecase: settingUsecase
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
        case "RRULE:FREQ=DAILY": return "Everyday"
        case "RRULE:FREQ=DAILY;INTERVAL=5": return "Every 5 Days"
        case "RRULE:FREQ=WEEKLY;BYDAY=TU": return "Every Week TUE"
        case "RRULE:FREQ=WEEKLY;INTERVAL=3;BYDAY=TU": return "Every 3 Weeks TUE"
        case "RRULE:FREQ=MONTHLY;BYDAY=-1WE": return "Every Month Last WED"
        case "RRULE:FREQ=MONTHLY;INTERVAL=3;BYDAY=2WE": return "Every 3 Months 2nd WED"
        case "RRULE:FREQ=MONTHLY;INTERVAL=2": return "Every 2 Months"
        case "RRULE:FREQ=YEARLY": return "Every Year"
        case "RRULE:FREQ=YEARLY;INTERVAL=3": return "Every 3 Years"
        case "RRULE:FREQ=WEEKLY;BYDAY=FR,MO,TH,TU,WE": return "Every Week FRI,MON,THU,TUE,WED"
        case "RRULE:FREQ=WEEKLY;WKST=MO;UNTIL=20250816T145959Z;BYDAY=SA": return "Every Week SAT\nuntil Aug 16, 2025"
        case "RRULE:FREQ=DAILY;COUNT=3": return "Everyday\n3 time(s)"
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
        let text = try await self.firstOutput(expect, for: viewModel.repeatOPtion) {
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

extension GoogleCalendarEventDetailViewModelImpleTests {
    
    @Test func viewModel_editEvent() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.refresh()
        
        // when
        viewModel.editEvent()
        
        // then
        #expect(self.spyRouter.didRouteToEditEventWebViewWithLink == "link")
    }
    
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
}

private final class PrivateStubGoogleCalendarUsecase: StubGoogleCalendarUsecase, @unchecked Sendable {
    
    var additionalStubbing: ((GoogleCalendar.EventOrigin) -> GoogleCalendar.EventOrigin)?
    
    override func eventDetail(
        _ calendarId: String, _ eventId: String, at timeZone: TimeZone
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
    
    var didRouteToEditEventWebViewWithLink: String?
    func routeToEditEventWebView(_ link: String) {
        self.didRouteToEditEventWebViewWithLink = link
    }
}
