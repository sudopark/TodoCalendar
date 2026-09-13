//
//  TodayWidgetViewModelTests.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics
import Domain

@testable import WidgetScenes


struct TodayWidgetViewModelTests {

    private func makeModel(_ style: TodayStyleSetting) -> TodayWidgetViewModel {
        return TodayWidgetViewModel(
            id: .init(2024, 3, 14),
            weekDayText: "THURSDAY",
            day: 14,
            monthAndYearText: "MAR 2024"
        )
        |> \.holidayName .~ "화이트데이"
        |> \.timeZoneText .~ "GMT"
        |> \.todoEventCount .~ 3
        |> \.scheduleEventcount .~ 4
        |> \.style .~ style
    }
}


// MARK: - 표시 항목 분기

extension TodayWidgetViewModelTests {

    @Test("스타일이 미설정이면 표시 항목 여섯을 전부 보인다")
    func displayItems_whenStyleNotSpecified_showAll() {
        // given
        let model = self.makeModel(.init())

        // when & then
        #expect(model.displayHolidayName == "화이트데이")
        #expect(model.displayTimeZoneText == "GMT")
        #expect(model.showsMonthAndYear == true)
        #expect(model.showsTotalCount == true)
        #expect(model.showsTodoCount == true)
        #expect(model.showsScheduleCount == true)
    }

    @Test("스타일이 년월을 끄면 년월만 감춘다")
    func showsMonthAndYear_whenStyleTurnsItOff_isFalse() {
        // given
        let model = self.makeModel(.init() |> \.showMonthYear .~ false)

        // when & then
        #expect(model.showsMonthAndYear == false)
        #expect(model.monthAndYearText == "MAR 2024")
        #expect(model.displayHolidayName == "화이트데이")
        #expect(model.showsTotalCount == true)
    }

    @Test("스타일이 공휴일명을 끄면 표시용 공휴일명만 사라진다")
    func displayHolidayName_whenStyleTurnsItOff_isNil() {
        // given
        let model = self.makeModel(.init() |> \.showHolidayName .~ false)

        // when & then
        #expect(model.displayHolidayName == nil)
        #expect(model.holidayName == "화이트데이")
        #expect(model.displayTimeZoneText == "GMT")
    }

    @Test("스타일이 타임존을 끄면 표시용 타임존 텍스트만 사라진다")
    func displayTimeZoneText_whenStyleTurnsItOff_isNil() {
        // given
        let model = self.makeModel(.init() |> \.showTimeZone .~ false)

        // when & then
        #expect(model.displayTimeZoneText == nil)
        #expect(model.timeZoneText == "GMT")
        #expect(model.displayHolidayName == "화이트데이")
    }

    @Test("스타일이 총 개수를 끄면 총 개수만 감춘다")
    func showsTotalCount_whenStyleTurnsItOff_isFalse() {
        // given
        let model = self.makeModel(.init() |> \.showTotalCount .~ false)

        // when & then
        #expect(model.showsTotalCount == false)
        #expect(model.showsTodoCount == true)
        #expect(model.showsScheduleCount == true)
    }

    @Test("스타일이 일정 개수를 끄면 일정 개수만 감춘다")
    func showsScheduleCount_whenStyleTurnsItOff_isFalse() {
        // given
        let model = self.makeModel(.init() |> \.showScheduleCount .~ false)

        // when & then
        #expect(model.showsScheduleCount == false)
        #expect(model.showsTodoCount == true)
        #expect(model.showsTotalCount == true)
    }

    @Test("할일 개수를 꺼도 총합은 할일을 그대로 센다")
    func totalEventCount_whenTodoCountTurnedOff_stillCountsTodo() {
        // given
        let model = self.makeModel(.init() |> \.showTodoCount .~ false)

        // when & then
        #expect(model.showsTodoCount == false)
        #expect(model.totalEventCount == 7)
    }
}


// MARK: - 하단 개수 줄 수

extension TodayWidgetViewModelTests {

    @Test("개수 항목 셋이 다 켜져 있으면 두 줄을 채운다")
    func eventCountLines_whenAllCountItemsOn_isBoth() {
        // given
        let model = self.makeModel(.init())

        // when & then
        #expect(model.eventCountLines == .both)
    }

    @Test("총 개수만 끄면 항목별 줄만 남는다")
    func eventCountLines_whenTotalCountTurnedOff_isOne() {
        // given
        let model = self.makeModel(.init() |> \.showTotalCount .~ false)

        // when & then
        #expect(model.eventCountLines == .one)
    }

    @Test("할일·일정 개수를 둘 다 끄면 총합 줄만 남는다")
    func eventCountLines_whenEachCountTurnedOff_isOne() {
        // given
        let model = self.makeModel(
            .init()
            |> \.showTodoCount .~ false
            |> \.showScheduleCount .~ false
        )

        // when & then
        #expect(model.eventCountLines == .one)
    }

    @Test("개수 항목 셋을 다 끄면 두 줄이 모두 빈다")
    func eventCountLines_whenAllCountItemsTurnedOff_isEmpty() {
        // given
        let model = self.makeModel(
            .init()
            |> \.showTotalCount .~ false
            |> \.showTodoCount .~ false
            |> \.showScheduleCount .~ false
        )

        // when & then
        #expect(model.eventCountLines == .empty)
    }

    @Test("총 개수를 껐고 남은 항목의 셀 값이 모두 0이면 두 줄이 모두 빈다")
    func eventCountLines_whenTotalOffAndRemainingCountsAreZero_isEmpty() {
        // given
        let model = self.makeModel(.init() |> \.showTotalCount .~ false)
            |> \.todoEventCount .~ 0
            |> \.scheduleEventcount .~ 0

        // when & then
        #expect(model.eventCountLines == .empty)
    }

    @Test("갤러리 샘플은 공휴일명과 타임존을 갖는다")
    func sample_hasHolidayNameAndTimeZone() {
        // given & when
        let sample = TodayWidgetViewModel.sample()

        // then
        #expect(sample.holidayName?.isEmpty == false)
        #expect(sample.timeZoneText == "GMT+9")
        #expect(sample.displayHolidayName == sample.holidayName)
        #expect(sample.displayTimeZoneText == sample.timeZoneText)
    }
}
