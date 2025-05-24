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
    
    private func makeViewModel() -> GoogleCalendarEventDetailViewModelImple {
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let calendarUsecase = PrivateStubGoogleCalendarUsecase()
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
        #expect(model?.colorId == "color")
        #expect(model?.colorHex == "hex")
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
}

private final class PrivateStubGoogleCalendarUsecase: StubGoogleCalendarUsecase, @unchecked Sendable {
    
    override func eventDetail(
        _ calendarId: String, _ eventId: String, at timeZone: TimeZone
    ) -> AnyPublisher<GoogleCalendar.EventOrigin, any Error> {
     
        let start = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2025-05-24T12:00:00+09:00"
        let end = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.dateTime .~ "2025-05-25T12:00:00+09:00"
        let origin = GoogleCalendar.EventOrigin(id: eventId, summary: "name")
            |> \.start .~ start
            |> \.end .~ end
            |> \.location .~ "location"
            |> \.htmlLink .~ "link"
        
        return Just(origin).mapAsAnyError().eraseToAnyPublisher()
    }
}

private final class SpyRouter: BaseSpyRouter, GoogleCalendarEventDetailRouting, @unchecked Sendable {
    
    var didRouteToEditEventWebViewWithLink: String?
    func routeToEditEventWebView(_ link: String) {
        self.didRouteToEditEventWebViewWithLink = link
    }
}
