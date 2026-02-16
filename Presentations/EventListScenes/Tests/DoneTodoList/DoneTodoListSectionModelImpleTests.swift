//
//  DoneTodoListSectionModelImpleTests.swift
//  EventListScenes
//
//  Created by sudo.park on 5/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import EventListScenes


class DoneTodoListSectionModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var stubTodoUsecase: PrivateStubTodoUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.stubTodoUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.stubTodoUsecase = nil
    }
    
    private func makeViewModel() -> DoneTodoEventListViewModelImple {
        let pagingUsecase = StubPagingUsecase()
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()
        
        let uiSettingUsecase = StubUISettingUsecase()
        _ = uiSettingUsecase.loadSavedAppearanceSetting()
        
        let viewModel = DoneTodoEventListViewModelImple(
            todoUsecase: self.stubTodoUsecase,
            pagingUsecase: pagingUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
    
    private var kst: TimeZone { TimeZone(abbreviation: "KST")! }
}

extension DoneTodoListSectionModelImpleTests {
    
    // test cvm
    func testDoneTodoCellViewModel() {
        // given
        let done = DoneTodoEvent(uuid: "some", name: "name", originEventId: "origin", doneTime: Date())
        
        // when
        let cvm = DoneTodoCellViewModel(done, self.kst, true)
        
        // then
        XCTAssertEqual(cvm.uuid, "some")
        XCTAssertEqual(cvm.name, "name")
    }
    
    private var refDate: Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ kst
        return calendar.dateBySetting(from: Date()) {
            $0.year = 2024
            $0.month = 05
            $0.day = 12
        }!
    }
    
    private func time(_ ref: Date = Date()) -> Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ kst
        return calendar.date(bySettingHour: 15, minute: 14, second: 0, of: ref)!
    }
    
    private var yesterDayTime: Date {
        return time(Date().add(days: -1)!)
    }
    
    func testDoneTodocellViewModel_eventTimeText() {
        // given
        func parameterizeTest(_ time: EventTime, is24: Bool, _ expectValue: String) {
            // given
            let done = DoneTodoEvent.dummy() |> \.eventTime .~ time
            // when
            let cvm = DoneTodoCellViewModel(done, kst, is24)
            
            // then
            XCTAssertEqual(cvm.eventTimeText, expectValue)
        }
        // when + then
        // time at
        parameterizeTest(
            .at(time().timeIntervalSince1970),
            is24: false,
            "\("eventList::today::title".localized()) PM 3:14"
        )
        parameterizeTest(
            .at(yesterDayTime.timeIntervalSince1970),
            is24: false,
            "\("eventList::yesterday::title".localized()) PM 3:14"
        )
        parameterizeTest(
            .at(time(self.refDate.add(days: -3)!).timeIntervalSince1970),
            is24: false,
            "05/09/2024 PM 3:14"
        )
        parameterizeTest(
            .at(time().timeIntervalSince1970),
            is24: true,
            "\("eventList::today::title".localized()) 15:14"
        )
        parameterizeTest(
            .at(yesterDayTime.timeIntervalSince1970),
            is24: true,
            "\("eventList::yesterday::title".localized()) 15:14"
        )
        parameterizeTest(
            .at(time(self.refDate.add(days: -3)!).timeIntervalSince1970),
            is24: true,
            "05/09/2024 15:14"
        )
        // period
        parameterizeTest(
            .period(
                self.time(self.refDate.add(days: -3)!).timeIntervalSince1970
                    ..<
                self.time().timeIntervalSince1970
            ), 
            is24: false,
            "05/09/2024 PM 3:14 ~ \("eventList::today::title".localized()) PM 3:14"
        )
        parameterizeTest(
            .period(
                self.time(self.refDate.add(days: -3)!).timeIntervalSince1970
                    ..<
                self.yesterDayTime.timeIntervalSince1970
            ), 
            is24: false,
            "05/09/2024 PM 3:14 ~ \("eventList::yesterday::title".localized()) PM 3:14"
        )
        // all day
        parameterizeTest(
            .allDay(
                self.time(self.refDate.add(days: -3)!).timeIntervalSince1970
                    ..<
                self.time().timeIntervalSince1970,
                secondsFromGMT: 32400
            ), 
            is24: false,
            "05/09/2024 ~ \("eventList::today::title".localized())"
        )
        parameterizeTest(
            .allDay(
                self.time(self.refDate.add(days: -3)!).timeIntervalSince1970
                    ..<
                self.yesterDayTime.timeIntervalSince1970,
                secondsFromGMT: 32400
            ),
            is24: false,
            "05/09/2024 ~ \("eventList::yesterday::title".localized())"
        )
    }
    
    // test section
    func testDoneTodoListSectionModel_sectionByTitle() {
        // given
        func makeDone(_ time: Date) -> DoneTodoEvent {
            return .init(uuid: UUID().uuidString, name: "some", originEventId: "s", doneTime: time)
        }
        // 자정에 돌리면 깨질수있음
        let todayDones = [
            makeDone(self.time().addingTimeInterval(-1)),
            makeDone(self.time().addingTimeInterval(-2)),
            makeDone(self.time().addingTimeInterval(-3))
        ]
        // 1월1일날 돌리면 깨질수있음
        let yesterdayDones = [
            makeDone(self.yesterDayTime.addingTimeInterval(-1)),
            makeDone(self.yesterDayTime.addingTimeInterval(-2))
        ]
        let lastYear = refDate.add(days: -365)!
        let lastYearDones = [
            makeDone(lastYear.addingTimeInterval(-1)),
            makeDone(lastYear.addingTimeInterval(-2)),
            makeDone(lastYear.addingTimeInterval(-3)),
            makeDone(lastYear.add(days: -1)!)
        ]
        
        // when
        let dones = todayDones + yesterdayDones + lastYearDones
        let sections = DoneTodoListSectionModel.builder(kst, true).build(dones)
        
        // then
        XCTAssertEqual(sections.count, 4)
        XCTAssertEqual(sections[safe: 0]?.sectionTitle, "eventList::today::title".localized())
        XCTAssertEqual(sections[safe: 0]?.cells.count, 3)
        XCTAssertEqual(sections[safe: 0]?.shouldShowSectionGroupTitle, true)
        XCTAssertEqual(sections[safe: 0]?.sectionGroupTitle, "eventList::today::title".localized())
        
        XCTAssertEqual(sections[safe: 1]?.sectionTitle, "eventList::yesterday::title".localized())
        XCTAssertEqual(sections[safe: 1]?.cells.count, 2)
        XCTAssertEqual(sections[safe: 1]?.shouldShowSectionGroupTitle, true)
        XCTAssertEqual(sections[safe: 1]?.sectionGroupTitle, "eventList::yesterday::title".localized())
        
        XCTAssertEqual(sections[safe: 2]?.sectionTitle, "05/13/2023")
        XCTAssertEqual(sections[safe: 2]?.cells.count, 3)
        XCTAssertEqual(sections[safe: 2]?.shouldShowSectionGroupTitle, true)
        XCTAssertEqual(sections[safe: 2]?.sectionGroupTitle, "2023".localized())
        
        XCTAssertEqual(sections[safe: 3]?.sectionTitle, "05/12/2023")
        XCTAssertEqual(sections[safe: 3]?.cells.count, 1)
        XCTAssertEqual(sections[safe: 3]?.shouldShowSectionGroupTitle, false)
        XCTAssertEqual(sections[safe: 3]?.sectionGroupTitle, "2023".localized())
    }
}

extension DoneTodoListSectionModelImpleTests {
    
    func testViewModel_provideDonetodosWithPaging() {
        // given
        let expect = expectation(description: "완료 todo list 페이징")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let sections = self.waitOutputs(expect, for: viewModel.sectionModels) {
            viewModel.loadList()
            viewModel.loadMoreList()
        }
        
        // then
        XCTAssertEqual(sections.count, 2)
    }
    
    func testViewModel_whenAfterRevertTodo_updateList() {
        // given
        let expect = expectation(description: "done todo revert 이후에 리스트 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let sections = self.waitOutputs(expect, for: viewModel.sectionModels) {
            viewModel.loadList()
            viewModel.revertDoneTodo("did:4")
        }
        
        // then
        let cellLists = sections.flatMap { ss in ss.map { $0.cells } }
        XCTAssertEqual(cellLists.count, 2)
        XCTAssertEqual(cellLists.first?.contains(where: { $0.uuid == "did:4" }), true)
        XCTAssertEqual(cellLists.last?.contains(where: { $0.uuid == "did:4" }), false)
    }
    
    func testViewModel_routeToDoneTodoDetail() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.selectDoneTodo("some")
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToDoneTodoDetail, "some")
    }
    
    func testViewModel_cancelRevertingTodo() {
        // given
        let expect = expectation(description: "cancel reverting todo")
        let viewModel = self.makeViewModel()
        
        // when
        let sections = self.waitOutputs(expect, for: viewModel.sectionModels) {
            viewModel.loadList()
            viewModel.revertDoneTodo("did:4")
            viewModel.cancelRevertDoneTodo("did:4")
        }
        
        // then
        let cellLists = sections.flatMap { ss in ss.map { $0.cells } }
        XCTAssertEqual(cellLists.count, 1)
        XCTAssertEqual(cellLists.first?.contains(where: { $0.uuid == "did:4" }), true)
    }
    
    func testViewModel_removeDoneTodos() {
        // given
        let expect = expectation(description: "완료 todo 삭제")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let sections = self.waitOutputs(expect, for: viewModel.sectionModels) {
            viewModel.loadList()
            viewModel.removeDoneTodos()
        }
        
        // then
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(self.spyRouter.didShowSelectRemoveDoneTodoRangePicker, true)
    }

    func testViewModel_whenRemoveTodo_updateIsRemoving() {
        // given
        let expect = expectation(description: "todo 삭제시에는 삭제중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isRemovings = self.waitOutputs(expect, for: viewModel.isRemovingTodos) {
            viewModel.loadList()
            viewModel.removeDoneTodos()
        }
        
        // then
        XCTAssertEqual(isRemovings, [false, true, false])
    }
}

private final class StubPagingUsecase: DoneTodoEventsPagingUsecase, @unchecked Sendable {
    let subjects = CurrentValueSubject<[DoneTodoEvent]?, Never>(nil)
    
    func reload() {
        let dones: [DoneTodoEvent] = (0..<10).map { .dummy($0) }
        self.subjects.send(dones)
    }
    func loadMore() {
        let dones: [DoneTodoEvent] = (10..<20).map { .dummy($0) }
        let new = (self.subjects.value ?? []) + dones
        self.subjects.send(new)
    }
    var events: AnyPublisher<[DoneTodoEvent]?, Never> {
        return self.subjects
            .eraseToAnyPublisher()
    }
    var loadFailed: AnyPublisher<any Error, Never> { Empty().eraseToAnyPublisher() }
}

private final class PrivateStubTodoUsecase: StubTodoEventUsecase {
    
    var revertIsDelayed: Bool = false
    
    override func revertCompleteTodo(_ doneId: String) async throws -> TodoEvent {
        guard revertIsDelayed == false
        else {
            try? await Task.sleep(for: .milliseconds(100))
            try Task.checkCancellation()
            return .init(uuid: "some", name: "name")
        }
        return .init(uuid: "some", name: "name")
    }
}

private final class SpyRouter: BaseSpyRouter, DoneTodoEventListRouting, @unchecked Sendable {
    
    var didShowSelectRemoveDoneTodoRangePicker: Bool?
    func showSelectRemoveDoneTodoRangePicker(_ selected: @escaping (RemoveDoneTodoRange) -> Void) {
        self.didShowSelectRemoveDoneTodoRangePicker = true
        selected(.olderThan3Months)
    }
    
    var didRouteToDoneTodoDetail: String?
    func routeToDoneTodoDetail(_ eventId: String) {
        self.didRouteToDoneTodoDetail = eventId
    }
}
