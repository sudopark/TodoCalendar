//
//  AddEventViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 10/15/23.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


class AddEventViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var refDate: Date!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.refDate = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.refDate = nil
    }
    
    private func makeViewModel(
        latestTagExists: Bool = true
    ) -> AddEventViewModelImple {
        
        let todoUsecase = StubTodoEventUsecase()
        let scheduleUsecase = StubScheduleEventUsecase()
        let tagUsecase = StubEventTagUsecase()
        tagUsecase.stubLatestUsecaseEventTag = latestTagExists ? .init(uuid: "latest", name: "some", colorHex: "some") : nil
        tagUsecase.prepare()
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.prepare()
        
        let viewModel = AddEventViewModelImple(
            todoUsecase: todoUsecase,
            scheduleUsecase: scheduleUsecase,
            eventTagUsease: tagUsecase,
            calendarSettingUsecase: settingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
    
    private var defaultCurrentAndNextHourSelectTime: SelectedTime {
        let now = self.refDate!; let next = now.addingTimeInterval(3600)
        let timeZone = TimeZone(abbreviation: "KST")!
        let dateForm = DateFormatter(); dateForm.timeZone = timeZone; dateForm.dateFormat = "MMM dd (E)".localized()
        let timeForm = DateFormatter(); timeForm.timeZone = timeZone; timeForm.dateFormat = "HH:00".localized()
        let nowDate = dateForm.string(from: now); let nowTime = timeForm.string(from: now)
        let nextDate = dateForm.string(from: next); let nextTime = timeForm.string(from: next)
        return .period(nowDate, nowTime, nextDate, nextTime)
    }
    
    private var dummyTimeAt: SelectedTime {
        let at = EventTime.at(self.refDate!.timeIntervalSince1970)
        let timeZone = TimeZone(abbreviation: "KST")!
        return .init(at, timeZone)
    }
    
    private var dummyPeriod: SelectedTime {
        let now = self.refDate!; let future = now.addingTimeInterval(3600 * 24 * 3)
        let timeZone = TimeZone(abbreviation: "KST")!
        let period = EventTime.period(now.timeIntervalSince1970..<future.timeIntervalSince1970)
        return .init(period, timeZone)
    }
    
    private var dummyPeriodDuringOneDay: SelectedTime {
        let now = self.refDate!; let future = now.addingTimeInterval(0.1)
        let timeZone = TimeZone(abbreviation: "KST")!
        let period = EventTime.period(now.timeIntervalSince1970..<future.timeIntervalSince1970)
        return .init(period, timeZone)
    }
    
    private var dummySingleAllDay: SelectedTime {
        let timeZone = TimeZone(abbreviation: "KST")!
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let start = calendar.startOfDay(for: self.refDate!); let end = calendar.endOfDay(for: start)!
        let period = EventTime.allDay(
            start.timeIntervalSince1970..<end.timeIntervalSince1970,
            secondsFromGMT: TimeInterval(timeZone.secondsFromGMT())
        )
        return .init(period, timeZone)
    }
    
    private var dummyAlldayPeriod: SelectedTime {
        let timeZone = TimeZone(abbreviation: "KST")!
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let now = self.refDate!; let future = now.addingTimeInterval(3600 * 24 * 3)
        let start = calendar.startOfDay(for: now); let end = calendar.endOfDay(for: future)!
        let period = EventTime.allDay(
            start.timeIntervalSince1970..<end.timeIntervalSince1970,
            secondsFromGMT: TimeInterval(timeZone.secondsFromGMT())
        )
        return .init(period, timeZone)
    }
}

// MARK: - initail value

extension AddEventViewModelImpleTests {
    
    // 최초에 현재시간 기준 현재~현재+1h로 시간 반환
    func testViewModel_initialEventTimeIsPeriodFromCurrentToNextHour() {
        // given
        let expect = expectation(description: "최초에 현재시간 기준 현재~현재+1h로 시간 반환")
        let viewModel = self.makeViewModel()
        
        // when
        let time = self.waitFirstOutput(expect, for: viewModel.selectedTime)
        
        // then
        XCTAssertEqual(time, self.defaultCurrentAndNextHourSelectTime)
    }
    
    // todo여부 토글
    func testViewModel_updateIsTodo() {
        // given
        let expect = expectation(description: "todo여부 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isTodos = self.waitOutputs(expect, for: viewModel.isTodo) {
            viewModel.toggleIsTodo()
            viewModel.toggleIsTodo()
        }
        
        // then
        XCTAssertEqual(isTodos, [false, true, false])
    }
    
    // 최초에 가장 마지막에 사용했던 태그값 반환
    func testViewModel_whenLatestUsedTagExists_provideSelectedTagAsLatestUsed() {
        // given
        let expect = expectation(description: "최초에 가장 마지막에 사용했던 태그값 반환")
        let viewModel = self.makeViewModel(latestTagExists: true)
        
        // when
        let tag = self.waitFirstOutput(expect, for: viewModel.selectedTag)
        
        // then
        XCTAssertEqual(tag?.tagId, .custom("latest"))
    }
    
    func testViewModel_whenLatestUsedTagNotExists_provideInitialSelectedTagIsDefault() {
        // given
        let expect = expectation(description: "마지막으로 사용했던 태그 존재하지 않으면 기본태그 반환")
        let viewModel = self.makeViewModel(latestTagExists: false)
        
        // when
        let tag = self.waitFirstOutput(expect, for: viewModel.selectedTag)
        
        // then
        XCTAssertEqual(tag?.tagId, .default)
    }
}


// MARK: - select

extension AddEventViewModelImpleTests {
    
    // 시간 선택 -> 선택 이후 선택된 시간 업데이트
    func testViewModel_whenAfterSelectTime_updateSelectedTime() {
        // given
        let expect = expectation(description: "기간 선택 이후에 선택된 날짜 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        viewModel.toggleIsTodo()
        
        // when
        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
            viewModel.selectTime()
            viewModel.eventTimeSelect(didSelect: nil)
        }
        
        // then
        XCTAssertEqual(times, [
            self.defaultCurrentAndNextHourSelectTime, nil
        ])
        XCTAssertEqual(self.spyRouter.didRouteToEventTimeSeelct, true)
        XCTAssertEqual(self.spyRouter.didRouteToEventTimeSelectWith.map { SelectedTime($0, TimeZone(abbreviation: "KST")!) }, self.defaultCurrentAndNextHourSelectTime)
        XCTAssertEqual(self.spyRouter.didRouteToEventTimeSelectWithNotSelectable, true)
    }
    
//    // time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜
//    func testViewModel_whenEventTimeIsTimeAtAndToggleIsAllDay_udpateSelectedTime() {
//        // given
//        let expect = expectation(description: "time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜")
//        expect.expectedFulfillmentCount = 4
//        let viewModel = self.makeViewModel()
//        
//        // when
//        let times = self.waitOutputs(expect, for: viewModel.selectedTime) {
//            viewModel.selectTime()
//            viewModel.eventTimeSelect(didSelect: .at(Date().timeIntervalSince1970))
//            
//            viewModel.toggleIsAllDay()
//            viewModel.toggleIsAllDay()
//        }
//        
//        // then
//        XCTAssertEqual(times, [
//            self.defaultCurrentAndNextHourSelectTime,
//            self.dummyTimeAt,
//            self.dummySingleAllDay,
//            self.dummyTimeAt
//        ])
//    }
//    
//    // time + period(복수일) => all day on -> 선택 복수날짜 allday => all day off -> 이전 선택한 날짜
//    
//    // time + period(단수일) => all day on -> 선택 단수일 allday => all day off -> 이전 선택한 날짜
    
    // 태그 선택
    
    // 반복옵션 선택
    
    // 장소 선택
}

// MARK: - save

extension AddEventViewModelImpleTests {
    
    // todo의 경우 이름만 입력하면 저장 가능해짐
    
    // schedule event의 경우 이름 및 시간이 입력되어야함
    
    // todo 저장
    
    // scheudle 저장
    
    // 저장시에 저장중임을 알림
}

private class SpyRouter: BaseSpyRouter, AddEventRouting, @unchecked Sendable {
    
    var didRouteToEventTimeSeelct: Bool?
    var didRouteToEventTimeSelectWith: EventTime?
    var didRouteToEventTimeSelectWithNotSelectable: Bool?
    func routeToEventTimeSelect(
        _ previousSelected: EventTime?,
        isNotSelectable: Bool
    ) {
        self.didRouteToEventTimeSeelct = true
        self.didRouteToEventTimeSelectWith = previousSelected
        self.didRouteToEventTimeSelectWithNotSelectable = isNotSelectable
    }
}
