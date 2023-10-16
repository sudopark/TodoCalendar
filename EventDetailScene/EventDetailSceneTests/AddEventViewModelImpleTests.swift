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
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
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
        let now = Date(); let next = now.addingTimeInterval(3600)
        let dateForm = DateFormatter(); dateForm.dateFormat = "MMM dd (E)".localized()
        let timeForm = DateFormatter(); timeForm.dateFormat = "HH:00".localized()
        let nowDate = dateForm.string(from: now); let nowTime = timeForm.string(from: now)
        let nextDate = dateForm.string(from: next); let nextTime = timeForm.string(from: next)
        XCTAssertEqual(time, .period(nowDate, nowTime, nextDate, nextTime))
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
    
    // time + at => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜
    
    // time + period => all day on -> 선택날짜 allday => all day off -> 이전 선택한 날짜
    
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
    
    
}
