//
//  SelectEventRepeatOptionViewModelTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 10/22/23.
//

import XCTest
import Combine
import Domain
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


class SelectEventRepeatOptionViewModelTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyListener: SpyListener!
    private var timeZone: TimeZone { TimeZone(abbreviation: "KST")! }
    
    private var defaultStartTime: Date { "2023-10-22 02:30:22".date() }
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyListener = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyListener = nil
    }
    
    private func makeViewModel(
        previous: EventRepeating? = nil
    ) -> SelectEventRepeatOptionViewModelImple {
        
        let settingUsecase = StubCalendarSettingUsecase()
        settingUsecase.selectTimeZone(self.timeZone)
        let viewModel = SelectEventRepeatOptionViewModelImple(
            startTime: self.defaultStartTime,
            previousSelected: previous,
            calendarSettingUsecase: settingUsecase
        )
        viewModel.listener = self.spyListener
        return viewModel
    }
}

extension SelectEventRepeatOptionViewModelTests {
    
    @discardableResult
    private func waitFirstNotEmptyOptionList(_ viewModel: SelectEventRepeatOptionViewModelImple) -> [SelectOptionModel]? {
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
    
    private var defaultOptionListTexts: [String] {
        [
            "not repeat".localized(),
            "Everyday".localized(),
            "Every Week".localized(),
            "every 2 week".localized(),
            "every 3 week".localized(),
            "every 4 week".localized(),
            "Every Month".localized(),
            "Every Year".localized(),
            "Every month last week all days".localized(),
            "\("Every month".localized()) 1\("week_suffix".localized()) \("weekday_1".localized())",
            "\("Every month".localized()) 2\("week_suffix".localized()) \("weekday_1".localized())",
            "\("Every month".localized()) 3\("week_suffix".localized()) \("weekday_1".localized())",
            "\("Every month".localized()) 4\("week_suffix".localized()) \("weekday_1".localized())",
            "\("Every month last".localized()) \("weekday_1".localized())"
        ]
    }
    
    // 이전 선택값 없을때 - 디폴트 선택옵션 리스트 제공
    func testViewModel_whenPreviousSelectNotExists_provideOptionList() {
        // given
        let viewModel = self.makeViewModel(previous: nil)
        
        // when
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // then
        XCTAssertEqual(options?.map { $0.text }, self.defaultOptionListTexts)
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
        XCTAssertEqual(id, options?.first(where: { $0.isNotRepeat })?.id)
    }
    
    // 이전 선텍값 있고 + 해당 옵션이 디폴트 선택 리스트에 있는 경우에 해당 옵션 선택한 상태로 제공
    func testViewModel_whenPreviousSelectExists_provideOptionListWithSelectIt() {
        // given
        let expect = expectation(description: "이전 선텍값 있고 + 해당 옵션이 디폴트 선택 리스트에 있는 경우에 해당 옵션 선택한 상태로 제공")
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryWeek(self.timeZone) |> \.interval .~ 2
        )
        let viewModel = self.makeViewModel(previous: previous)
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let id = self.waitFirstOutput(expect, for: viewModel.selectedOptionId)
        
        // then
        XCTAssertNotNil(id)
        let weekPer2Id = options?.first(where: { $0.text == "every 2 week".localized() })?.id
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
        let findingText = "\("Every month".localized()) 3\("week_suffix".localized()) \("weekday_4".localized())"
        let week3thWedId = options?.first(where: { $0.text == findingText })?.id
        XCTAssertEqual(id, week3thWedId)
        XCTAssertEqual(options?.count, self.defaultOptionListTexts.count + 1)
    }
    
    // 반복 옵션 선택시에 선택된 이벤트 아이디 변경
    func testViewModel_whenSelectionIdChanged_updateSelectedId() {
        // given
        let expect = expectation(description: "반복 옵션 선택시에 선택된 이벤트 아이디 변경")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
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
    func testViewModel_whenPreviousSelectNotExists_repeatEndTimeIsMonthLastDayAndOff() {
        // given
        let expect = expectation(description: "이전 선택값 없을떄 - 초기 종료 시간은 해당 월의 마지막일 + off")
        let viewModel = self.makeViewModel()
        
        // when
        let endTimeOfIsOn = Publishers.CombineLatest(viewModel.repeatEndTimeText, viewModel.hasRepeatEnd)
        let endTime = self.waitFirstOutput(expect, for: endTimeOfIsOn) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(endTime?.0, "2023.10.31")
        XCTAssertEqual(endTime?.1, false)
    }
    
    // 이전 선택값에 이벤트 종료시간 포함되는 경우 해당 시간 노출
    func testViewModel_whenPreviousSelectExists_repeatEndTimeIsPreviousAndOn() {
        // given
        let expect = expectation(description: "이전 선택값에 이벤트 종료시간 포함되는 경우 해당 시간 노출")
        let previous = EventRepeating(
            repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
            repeatOption: EventRepeatingOptions.EveryDay()
        )
        |> \.repeatingEndTime .~ "2023.11.30 10:33:33".date().timeIntervalSince1970
        let viewModel = self.makeViewModel(previous: previous)
        
        // when
        let endTimeOfIsOn = Publishers.CombineLatest(viewModel.repeatEndTimeText, viewModel.hasRepeatEnd)
        let endTime = self.waitFirstOutput(expect, for: endTimeOfIsOn) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertEqual(endTime?.0, "2023.11.30")
        XCTAssertEqual(endTime?.1, true)
    }
    
    // 이벤트 종료시간 토글
    func testViewModel_toggleHasEventEndTime() {
        // given
        let expect = expectation(description: "이벤트 종료시간 토글")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.hasRepeatEnd) {
            viewModel.prepare()
            viewModel.toggleHasRepeatEnd(isOn: true)
            viewModel.toggleHasRepeatEnd(isOn: false)
        }
        
        // then
        XCTAssertEqual(isOns, [false, true, false])
    }
    
    // 이벤트 종료시간 선택시에 off 되어있으면 자동으로 on 시킴
    func testViewModel_whenUpdateEvnetEndtime_updateTime() {
        // given
        let expect = expectation(description: "이벤트 종료시간 선택시에 텍스트 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let texts = self.waitOutputs(expect, for: viewModel.repeatEndTimeText) {
            viewModel.selectRepeatEndDate("2023.10.28 12:33:33".date())
            viewModel.selectRepeatEndDate("2024.01.01 00:00:00".date())
        }
        
        // then
        XCTAssertEqual(texts, [
            "2023.10.31", "2023.10.28", "2024.01.01"
        ])
    }
    
    func testViewModel_whenUpdateEvnetEndtime_updateTimeAndTurnOnIfOffed() {
        // given
        let expect = expectation(description: "이벤트 종료시간 선택시에 off 되어있으면 자동으로 on 시킴")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let isOns = self.waitOutputs(expect, for: viewModel.hasRepeatEnd) {
            viewModel.selectRepeatEndDate("2023.10.28 12:33:33".date())
            viewModel.selectRepeatEndDate("2024.01.01 00:00:00".date())
        }
        
        // then
        XCTAssertEqual(isOns, [
            false, true
        ])
    }
}

extension SelectEventRepeatOptionViewModelTests {
    
    // 반복 옵션 선택시마다 외부로 이벤트 전파
    func testViewModel_whenAfterSelectOption_notify() {
        // given
        let viewModel = self.makeViewModel()
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let everyDay = options!.first(where: { $0.text == "Everyday".localized() })!
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
        let options = self.waitFirstNotEmptyOptionList(viewModel)
        
        // when
        let everyDay = options?.first(where: { $0.text == "Everyday".localized() })
        viewModel.selectRepeatEndDate("2023.11.20 00:00:00".date()) // end time 지정은 하지만 반복안함 옵션임 -> not select
        viewModel.selectOption(everyDay?.id ?? "") // 반복설정 생기면서 종료시간이랑 같이 업데이트
        viewModel.toggleHasRepeatEnd(isOn: false) // notify
        viewModel.selectRepeatEndDate("2023.11.24 00:00:00".date())
        
        XCTAssertEqual(self.spyListener.didEventRepeatingSelectOrNot, [
            nil,
            EventRepeating(
                repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
                repeatOption: EventRepeatingOptions.EveryDay()
            ) |> \.repeatingEndTime .~ "2023.11.20 02:30:22".date().timeIntervalSince1970,
            EventRepeating(
                repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
                repeatOption: EventRepeatingOptions.EveryDay()
            ),
            EventRepeating(
                repeatingStartTime: self.defaultStartTime.timeIntervalSince1970,
                repeatOption: EventRepeatingOptions.EveryDay()
            ) |> \.repeatingEndTime .~ "2023.11.24 02:30:22".date().timeIntervalSince1970,
        ])
    }
}

private class SpyListener: SelectEventRepeatOptionSceneListener {
    
    var didEventRepeatingSelectOrNot: [EventRepeating?] = []
    func selectEventRepeatOption(didSelect repeating: EventRepeating) {
        self.didEventRepeatingSelectOrNot.append(repeating)
    }
    
    func selectEventRepeatOptionNotRepeat() {
        self.didEventRepeatingSelectOrNot.append(nil)
    }
}
