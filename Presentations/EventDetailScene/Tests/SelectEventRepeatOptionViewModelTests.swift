//
//  SelectEventRepeatOptionViewModelTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 10/22/23.
//

import XCTest
import Combine
import Domain
import Extensions
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


class SelectEventRepeatOptionViewModelTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyListener: SpyListener!
    private var spyRouter: SpyRouter!
    private var timeZone: TimeZone { TimeZone(abbreviation: "KST")! }
    
    private var defaultStartTime: Date { "2023-10-22 02:30:22".date() }
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyListener = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyListener = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel(
        previous: EventRepeating? = nil
    ) -> SelectEventRepeatOptionViewModelImple {
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.selectTimeZone(self.timeZone)
        let viewModel = SelectEventRepeatOptionViewModelImple(
            selectTime: self.defaultStartTime,
            previousSelected: previous,
            calendarSettingUsecase: settingUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }
}

extension SelectEventRepeatOptionViewModelTests {
    
    @discardableResult
    private func waitFirstNotEmptyOptionList(_ viewModel: SelectEventRepeatOptionViewModelImple) -> [[SelectRepeatingOptionModel]]? {
        // given
        let expect = expectation(description: "wait not empty option model list")
        expect.assertForOverFulfill = false
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.options.filter { !$0.isEmpty }) {
            viewModel.prepare()
        }
        
        // then
        return models
    }
    
    private var defaultOptionListTexts: [[String]] {
        [
            [
                "eventDetail.repeating.notRepeating::title".localized(),
            ],
            [
                "eventDetail.repeating.everyDay:title".localized(),
                "eventDetail.repeating.everyWeek:title".localized(),
                "eventDetail.repeating.everySomeWeek:title".localized(with: 2),
                "eventDetail.repeating.everySomeWeek:title".localized(with: 3),
                "eventDetail.repeating.everySomeWeek:title".localized(with: 4),
                "eventDetail.repeating.everyMonth:title".localized(),
                "eventDetail.repeating.everyYear:title".localized(),
            ],
            [
                "eventDetail.repeating.everyLastWeekDaysOfEveryMonth:title".localized(),
                "eventDetail.repeating.every1WeekOfEveryMonth::someday".localized(with: "Sunday"),
                "eventDetail.repeating.every2WeekOfEveryMonth::someday".localized(with: "Sunday"),
                "eventDetail.repeating.every3WeekOfEveryMonth::someday".localized(with: "Sunday"),
                "eventDetail.repeating.every4WeekOfEveryMonth::someday".localized(with: "Sunday"),
                "eventDetail.repeating.everyLastWeekOfEveryMonth::someday".localized(with: "Sunday")
            ]
        ]
    }
    
    func testViewModel_provideRepeatStartTime() {
        // given
        func parameterizeTest(
            _ description: String, previous: EventRepeating?, _ expectText: String?
        ) {
            // given
            let expect = expectation(description: "wait start time")
            let viewModel = self.makeViewModel(previous: previous)
            
            // when
            let text = self.waitFirstOutput(expect, for: viewModel.repeatStartTimeText) {
                viewModel.prepare()
            }
            
            // then
            XCTAssertEqual(text, expectText)
        }
        
        // when + then
        let option = EventRepeating(
            repeatingStartTime: Date(timeIntervalSince1970: 0).timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryWeek(self.timeZone)
                |> \.interval .~ 1
        )
        parameterizeTest("반복옵션 있으면 옵션의 시작시간", previous: option, "Jan 1, 1970")
        parameterizeTest("반복옵션 없으면 현재 선택된 시간", previous: nil, "Oct 22, 2023")
    }
    
    // 이전 선택값 없을때 - 디폴트 선택옵션 리스트 제공
    func testViewModel_whenPreviousSelectNotExists_provideOptionList() {
        // given
        let viewModel = self.makeViewModel(previous: nil)
        
        // when
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // then
        XCTAssertEqual(options?.map { os in os.map { $0.text } }, self.defaultOptionListTexts)
    }
    
    func testViewModel_whenProvideEveryWeekRepeatOption_provideWeekDay() {
        // given
        let viewModel = self.makeViewModel(previous: nil)
        
        // when
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // then
        let everyWeeks = options?.flatMap { $0 }
            .compactMap { $0.option as? EventRepeatingOptions.EveryWeek }
        let intervals = everyWeeks?.map { $0.interval }
        let weekDays = everyWeeks?.map { $0.dayOfWeeks }
        XCTAssertEqual(intervals, [1, 2, 3, 4])
        XCTAssertEqual(weekDays, [[.sunday], [.sunday], [.sunday], [.sunday]])
    }
    
    // 이전 선택값 없을때 - 디폴트로 반복없음 선택 상태
    func testViewModel_whenPreviousSelectNotExists_selectNotRepeatOption() {
        // given
        let expect = expectation(description: "이전 선택값 없을때 - 디폴트로 반복없음 선택 상태")
        let viewModel = self.makeViewModel(previous: nil)
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let id = self.waitFirstOutput(expect, for: viewModel.selectedOptionId)
        
        // then
        XCTAssertNotNil(id)
        XCTAssertEqual(id, options?.flatMap { $0 }.first(where: { $0.isNotRepeat })?.id)
    }
    
    // 이전 선텍값 있고 + 해당 옵션이 디폴트 선택 리스트에 있는 경우에 해당 옵션 선택한 상태로 제공
    func testViewModel_whenPreviousSelectExists_provideOptionListWithSelectIt() {
        // given
        let expect = expectation(description: "이전 선텍값 있고 + 해당 옵션이 디폴트 선택 리스트에 있는 경우에 해당 옵션 선택한 상태로 제공")
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryWeek(self.timeZone) 
                |> \.interval .~ 2
                |> \.dayOfWeeks .~ [.sunday]
        )
        let viewModel = self.makeViewModel(previous: previous)
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let id = self.waitFirstOutput(expect, for: viewModel.selectedOptionId)
        
        // then
        XCTAssertNotNil(id)
        let weekPer2Id = options?.flatMap { $0 }.first(where: { $0.text == "eventDetail.repeating.everySomeWeek:title".localized(with: 2) })?.id
        XCTAssertEqual(id, weekPer2Id)
        XCTAssertEqual(options?.count, self.defaultOptionListTexts.count)
    }
    
    // 이전 선택값 있지만 + 디폴트 선택 리스트에 해당 옵션이 없는 경우 이전 옵션 노출하고 해당 옵션 선택한 상태로 제공
    func testViewModel_whenPreviousSelectExistButNotInCurrentSelectOption_providePreviousWithSelectIt() {
        // given
        let expect = expectation(description: "이전 선택값 있지만 + 디폴트 선택 리스트에 해당 옵션이 없는 경우 이전 옵션 노출하고 해당 옵션 선택한 상태로 제공")
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryMonth(timeZone: self.timeZone)
            |> \.selection .~ .week([.seq(3)], [.wednesday])
        )
        let viewModel = self.makeViewModel(previous: previous)
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let id = self.waitFirstOutput(expect, for: viewModel.selectedOptionId)
        
        // then
        XCTAssertNotNil(id)
        let findingText = "eventDetail.repeating.every3WeekOfEveryMonth::someday".localized(with: "Wednesday")
        let week3thWedId = options?.flatMap { $0 }.first(where: { $0.text == findingText })?.id
        XCTAssertEqual(id, week3thWedId)
        let allItemCount = options?.flatMap { $0 }.count
        XCTAssertEqual(allItemCount, self.defaultOptionListTexts.flatMap { $0 }.count + 1)
    }
    
    // 반복 옵션 선택시에 선택된 이벤트 아이디 변경
    func testViewModel_whenSelectionIdChanged_updateSelectedId() {
        // given
        let expect = expectation(description: "반복 옵션 선택시에 선택된 이벤트 아이디 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        let options = self.waitFirstNotEmptyOptionList(viewModel)?.flatMap { $0 }
        
        // when
        let second = options?[safe: 1]; let last = options?.last
        let ids = self.waitOutputs(expect, for: viewModel.selectedOptionId) {
            viewModel.selectOption(second?.id ?? "")
            viewModel.selectOption(last?.id ?? "")
        }
        
        // then
        XCTAssertEqual(ids, [
            options?.first(where: { $0.isNotRepeat })?.id,
            second?.id,
            last?.id
        ])
    }
}

extension SelectEventRepeatOptionViewModelTests {
    
    // 이전 선택값 없을떄 - 초기 종료 시간은 해당 월의 마지막일 + off
    func testViewModel_provideDefaultRepeatEndDate() {
        // given
        let expect = expectation(description: "기본 이벤트 종료시간 정보 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let date = self.waitFirstOutput(expect, for: viewModel.defaultRepeatEndDate) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(date?.text("yyyy.MM.dd HH:mm:ss", timeZone: TimeZone(abbreviation: "KST")!), "2023.10.31 23:59:59")
    }
    
    func testViewModel_whenEndOptionNotExists_provideNeverOption() {
        // given
        let expect = expectation(description: "반복 종료 옵션이 없는경우, 반복종료 없음 옵션모델 제공")
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        let viewModel = self.makeViewModel(previous: previous)
        
        // when
        let option = self.waitFirstOutput(expect, for: viewModel.repeatEndOption) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(option?.isNever, true)
    }
    
    func testViewModel_whenPreviousEndOptionIsOn_provideDateInfo() {
        // given
        let expect = expectation(description: "이전 선택값에 이벤트 종료시간 포함되는 경우 해당 시간 노출")
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        |> \.repeatingEndOption .~ .until(
            "2023.11.30 10:33:33".date().timeIntervalSince1970
        )
        let viewModel = self.makeViewModel(previous: previous)
        
        // when
        let option = self.waitFirstOutput(expect, for: viewModel.repeatEndOption) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(option?.endDateText, "11/30/2023")
        XCTAssertEqual(option?.endDate, "2023.11.30 23:59:59".date())
    }
    
    func testViewModel_whenPreviousEndOptionIsAfter_provideCountInfo() {
        // given
        let expect = expectation(description: "이전에 선택한 종료 옵션이 횟수인경우, 횟수정보 제공")
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        |> \.repeatingEndOption .~ .count(100)
        let viewModel = self.makeViewModel(previous: previous)
        
        // when
        let option = self.waitFirstOutput(expect, for: viewModel.repeatEndOption) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(option?.endCount, 100)
    }
    
    func testViewModel_updateSelectRepeatEndOption() {
        // given
        let expect = expectation(description: "이벤트 종료 옵션 변경")
        expect.expectedFulfillmentCount = 4
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        let viewModel = self.makeViewModel(previous: previous)
        
        // when
        let options = self.waitOutputs(expect, for: viewModel.repeatEndOption) {
            viewModel.prepare()
            
            viewModel.selectRepeatEndDate("2023.11.30 10:33:33".date())
            viewModel.selectRepeatEndCount(33)
            viewModel.removeRepeatEndOption()
        }
        
        // then
        XCTAssertEqual(options[safe: 0]?.isNever, true)
        XCTAssertEqual(options[safe: 1]?.endDateText, "11/30/2023")
        XCTAssertEqual(options[safe: 2]?.endCount, 33)
        XCTAssertEqual(options[safe: 3]?.isNever, true)
    }
    
    func testViewMode_whenSelectNoRepeatOptionOrNot_updateIsNoRepeat() {
        // given
        let expect = expectation(description: "이벤트 반복 옵션 선택 유무에 따라, 플래그 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        let options = self.waitFirstNotEmptyOptionList(viewModel)?.flatMap { $0 }
        let noRepeatOption = options!.first(where: { $0.isNotRepeat == true })!
        let repeatingOption = options!.first(where: { $0.isNotRepeat == false })!
        
        // when
        let isNoOptions = self.waitOutputs(expect, for: viewModel.isNoRepeatOption) {
            viewModel.selectOption(repeatingOption.id)
            viewModel.selectOption(noRepeatOption.id)
        }
        
        // then
        XCTAssertEqual(isNoOptions, [true, false, true])
    }
}

extension SelectEventRepeatOptionViewModelTests {
    
    // 반복 옵션 선택시마다 외부로 이벤트 전파
    func testViewModel_whenAfterSelectOption_notify() {
        // given
        let viewModel = self.makeViewModel()
        let options = self.waitFirstNotEmptyOptionList(viewModel)?.flatMap { $0 }
        
        // when
        let everyDay = options!.first(where: { $0.text == "eventDetail.repeating.everyDay:title".localized() })!
        let notRepeat = options!.first(where: { $0.isNotRepeat })!
        viewModel.selectOption(everyDay.id)
        viewModel.selectOption(notRepeat.id)
        
        // then
        XCTAssertEqual(self.spyListener.didEventRepeatingSelectOrNot.map { $0?.repeatOption.compareHash }, [
            EventRepeatingOptions.EveryDay().compareHash,
            nil
        ])
    }
    
    // 종료시간 변경시에도 외부로 이벤트 전파
    func testViewModel_whenUpdateEndTime_notify() {
        // given
        let viewModel = self.makeViewModel()
        let options = self.waitFirstNotEmptyOptionList(viewModel)?.flatMap { $0 }
        
        // when
        let everyDay = options?.first(where: { $0.text == "eventDetail.repeating.everyDay:title".localized() })

        viewModel.selectOption(everyDay?.id ?? "") // 반복설정 생기면서 종료시간이랑 같이 업데이트
        viewModel.selectRepeatEndDate("2023.11.24 00:00:00".date())
        
        XCTAssertEqual(self.spyListener.didEventRepeatingSelectOrNot, [
            EventRepeating(
                repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
                repeatOption: EventRepeatingOptions.EveryDay()
            ),
            EventRepeating(
                repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
                repeatOption: EventRepeatingOptions.EveryDay()
            ) |> \.repeatingEndOption .~ .until("2023.11.24 23:59:59".date().timeIntervalSince1970),
        ])
    }
    
    private func makeViewModelWithPreviousRepeating() -> SelectEventRepeatOptionViewModelImple {
        let previous = EventRepeating(
            repeatingStartTime: 100,
            repeatOption: EventRepeatingOptions.EveryMonth(timeZone: self.timeZone)
            |> \.selection .~ .week([.seq(3)], [.wednesday])
        )
        return self.makeViewModel(previous: previous)
    }
    
    func testViewModel_whenPreviousOptionExistsAndChanged_notUpdateStartTime() {
        // given
        let viewModel = self.makeViewModelWithPreviousRepeating()
        viewModel.prepare()
        
        // when
        viewModel.selectRepeatEndCount(3)
        
        // then
        XCTAssertEqual(self.spyListener.didEventRepeatingSelectOrNot.count, 1)
        let first = self.spyListener.didEventRepeatingSelectOrNot.first
        XCTAssertEqual(first??.repeatingStartTime, 100)
    }
    
    func testViewModel_whenSelectedRepeatingEndTimeIsInvalid_showToast() {
        // given
        let viewModel = self.makeViewModelWithPreviousRepeating()
        viewModel.prepare()
        
        // when
        let endDate = Date(timeIntervalSince1970: 0).add(days: -10)!
        viewModel.selectRepeatEndDate(endDate)
        
        // then
        XCTAssertEqual(self.spyListener.didEventRepeatingSelectOrNot.count, 1)
        let first = self.spyListener.didEventRepeatingSelectOrNot.first
        XCTAssertEqual(first??.repeatingEndOption?.endTime, nil)
        XCTAssertEqual(self.spyRouter.didShowRepeatingEndTimeIsInvalid, true)
    }
    
    func testViewModel_whenSelectRepeatingEndTimeIsInvalid_toggleOffHasEndTime() {
        // given
        let expect = expectation(description: "종료시간이 유효하지 않은경우(시작시간보다 미래가 아님) 종료시간이 없도록 다시 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModelWithPreviousRepeating()
        viewModel.prepare()
        
        // when
        let options = self.waitOutputs(expect, for: viewModel.repeatEndOption) {
            let endDate = Date(timeIntervalSince1970: 0).add(days: -10)!
            viewModel.selectRepeatEndDate(endDate)
        }
        
        // then
        XCTAssertEqual(options.map{ $0.isNever }, [true, false, true])
    }
}

private class SpyListener: SelectEventRepeatOptionSceneListener, @unchecked Sendable {
    
    var didEventRepeatingSelectOrNot: [EventRepeating?] = []
    func selectEventRepeatOption(didSelect repeating: EventRepeatingTimeSelectResult) {
        self.didEventRepeatingSelectOrNot.append(repeating.repeating)
    }
    
    func selectEventRepeatOptionNotRepeat() {
        self.didEventRepeatingSelectOrNot.append(nil)
    }
}

private class SpyRouter: BaseSpyRouter, SelectEventRepeatOptionRouting, @unchecked Sendable {
    
    var didShowRepeatingEndTimeIsInvalid: Bool?
    func showRepeatingEndTimeIsInvalid(startDate: Date) {
        self.didShowRepeatingEndTimeIsInvalid = true
    }
}

private extension RepeatEndOptionModel {
    
    var isNever: Bool {
        guard case .never = self else { return false }
        return true
    }
    
    var endCount: Int? {
        guard case .after(let count) = self else { return nil }
        return count
    }
    
    var endDateText: String? {
        guard case .on(let date) = self else { return nil }
        return date.text
    }
}
