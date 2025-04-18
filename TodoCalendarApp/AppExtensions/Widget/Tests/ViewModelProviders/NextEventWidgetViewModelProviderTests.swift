//
//  NextEventWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 1/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes
import UnitTestHelpKit
import TestDoubles


class NextEventWidgetViewModelProviderTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var kst: TimeZone { TimeZone(abbreviation: "KST")! }
    
    private func makeProvider(
        _ nextEvent: TodayNextEvent?
    ) -> NextEventWidgetViewModelProvider {
        let eventFetchUsecase = StubCalendarEventsFetchUescase()
        eventFetchUsecase.stubNextEvent = nextEvent
        
        let calendarSettingRepository = StubCalendarSettingRepository()
        calendarSettingRepository.saveTimeZone(self.kst)
        
        let appSettingRepository = StubAppSettingRepository()
        
        return .init(
            eventsFetchusecase: eventFetchUsecase,
            appSettingRepository: appSettingRepository,
            calednarSettingRepository: calendarSettingRepository
        )
    }
}


extension NextEventWidgetViewModelProviderTests {
    
    // 다음 이벤트 없는경우
    @Test func provideEmptyModel_whenNextEventNotExists() async throws {
        // given
        let provider = self.makeProvider(nil)
        
        // when
        let model = try await provider.getNextEventModel(for: Date(timeIntervalSince1970: 0))
        
        // then
        #expect(model.timeText == nil)
        #expect(model.eventTitle == "widget.next.noEvent".localized())
        #expect(model.refreshAfter == nil)
    }
    
    // 다음 이벤트가 todo인 경우
    private var nextTodo: TodayNextEvent {
        let todo = TodoEvent(uuid: "todo", name: "todo")
            |> \.time .~ .period(1000..<2000)
        let event = TodoCalendarEvent(todo, in: self.kst)
        return .init(nextEvent: event, tag: nil)
    }
    
    @Test func provideNextEventIsTodo() async throws {
        // given
        let provider = self.makeProvider(self.nextTodo)
        
        // when
        let model = try await provider.getNextEventModel(for: Date(timeIntervalSince1970: 0))
        
        // then
        #expect(model.timeText == "9:16")
        #expect(model.eventTitle == "todo")
        #expect(model.refreshAfter == nil)
    }
    
    
    enum SecondNextEventTime: TimeInterval {
        case gtThanFirstEndTime = 3000
        case lsThenFirstEndTime = 1800
        case lsThenFirstEndTimeAndBefore10minLsThanFirstStartTime = 1200
    }
    
    @Test("그 다음 이벤트 시간에 따라 다음 갱신시간 결정", arguments: [
        SecondNextEventTime.gtThanFirstEndTime, .lsThenFirstEndTime, .lsThenFirstEndTimeAndBefore10minLsThanFirstStartTime
    ])
    func provider_selectNextEventRefreshTime(_ secondsNextEventTime: SecondNextEventTime?) async throws {
        // given
        let secondTime = secondsNextEventTime.map { Date(timeIntervalSince1970: $0.rawValue) }
        let dummy = self.nextTodo |> \.andThenNextEventStartDate .~ secondTime
        let provider = self.makeProvider(dummy)
        
        // when
        let model = try await provider.getNextEventModel(for: Date(timeIntervalSince1970: 0))
        
        // then
        switch secondsNextEventTime {
        case .gtThanFirstEndTime:
            let firstEventEndDate = Date(timeIntervalSince1970: dummy.nextEvent.eventTime!.upperBoundWithFixed)
            #expect(model.refreshAfter == firstEventEndDate)
            
        case .lsThenFirstEndTime:
            let secondEventStartTimeBefore10Min = Date(
                timeIntervalSince1970: SecondNextEventTime.lsThenFirstEndTime.rawValue-10*60
            )
            #expect(model.refreshAfter == secondEventStartTimeBefore10Min)
            
        case .lsThenFirstEndTimeAndBefore10minLsThanFirstStartTime:
            let secondEventStartTime = Date(timeIntervalSince1970: dummy.nextEvent.eventTime!.lowerBoundWithFixed)
            #expect(model.refreshAfter == secondEventStartTime)
            
        case .none:
            #expect(model.refreshAfter == nil)
        }
    }
}
