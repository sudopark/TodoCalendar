//
//  ForemostEventWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 7/17/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes
import UnitTestHelpKit
import TestDoubles


class ForemostEventWidgetViewModelProviderTests: XCTestCase {
    
    private func makeProvider(
        _ foremostEvent: (any ForemostMarkableEvent)?,
        shouldFail: Bool = false
    ) -> ForemostEventWidgetViewModelProvider {
        
        let usecase = PrivateStubEventFetchUsecase()
        usecase.shouldFailFetchForemost = shouldFail
        usecase.foremostEvent = foremostEvent
        
        let calendarSettingRepository = StubCalendarSettingRepository()
        let appSettingRepository = StubAppSettingRepository()
        
        return .init(
            eventFetchUsecase: usecase,
            calendarSettingRepository: calendarSettingRepository,
            appSettingRepository: appSettingRepository
        )
    }
    
    private var kst: TimeZone { TimeZone(abbreviation: "KST")! }
    
    private var refTime: Date {
        let calenadr = Calendar(identifier: .gregorian) |> \.timeZone .~ self.kst
        return calenadr.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 3; $0.day = 1
        }!
    }
    
    private var dummyTodo: TodoEvent {
        return TodoEvent(uuid: "todo", name: "todo")
    }
    
    private var dummySchedule: ScheduleEvent {
        return ScheduleEvent(uuid: "schedule", name: "schedule", time: .at(refTime.timeIntervalSince1970 + 10))
    }
    
    private var dummPastSchedule: ScheduleEvent {
        let past = self.refTime.add(days: -1)!
        return ScheduleEvent(uuid: "past-schedule", name: "past-schedule", time: .at(past.timeIntervalSince1970))
    }
}


extension ForemostEventWidgetViewModelProviderTests {
    
    // foremost event: todo인 경우
    func testProvider_provideForemostEvent_isTodo() async throws {
        // given
        let provider = self.makeProvider(self.dummyTodo)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertEqual(model.eventModel?.eventIdentifier, "todo")
    }
    
    // foremost event: schedule event 인 경우
    func testProvider_provideForemostEvent_isScheduleEvent() async throws {
        // given
        let provider = self.makeProvider(self.dummySchedule)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertEqual(model.eventModel?.eventIdentifier, "schedule-1")
    }
    
    // foremost event: 이미 지난 schedule event 인 경우 -> 없는것으로 취급
    func testProvider_whenForemostEventIsPastScheduleEvent_regardAsNotExists() async throws {
        // given
        let provider = self.makeProvider(self.dummPastSchedule)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertNil(model.eventModel)
    }
    
    // 없는경우 결과 nil
    func testProvider_provideFremostEvnet_notExists() async throws {
        // given
        let provider = self.makeProvider(nil)
        
        // when
        let model = try await provider.getViewModel(self.refTime)
        
        // then
        XCTAssertNil(model.eventModel)
    }
    
    // 조회 실패시 에러
    func testProvider_whenProvideFailed_error() async {
        // given
        let provider = self.makeProvider(nil, shouldFail: true)
        var failed: (any Error)?
        // when
        do {
            _ = try await provider.getViewModel(self.refTime)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
}

private final class PrivateStubEventFetchUsecase: StubCalendarEventsFetchUescase {
    
    var shouldFailFetchForemost: Bool = false
    var foremostEvent: (any ForemostMarkableEvent)?
    override func fetchForemostEvent() async throws -> ForemostEvent {
        guard self.shouldFailFetchForemost == false
        else {
            throw RuntimeError("failed")
        }
        
        return .init(foremostEvent: foremostEvent, tag: nil)
    }
}
