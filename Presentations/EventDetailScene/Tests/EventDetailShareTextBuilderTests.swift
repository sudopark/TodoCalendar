//
//  EventDetailShareTextBuilderTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Extensions
import CommonPresentation

@testable import EventDetailScene


struct EventDetailShareTextBuilderTests {

    private let builder = EventDetailShareTextBuilder()
    private let timeZone = TimeZone(abbreviation: "KST")!
}


// MARK: - build(_:) 라벨 필드 조립

extension EventDetailShareTextBuilderTests {

    private func label(_ key: String) -> String {
        return "event_detail::share::field::\(key)".localized()
    }

    private var tagLabel: String { "eventTag.title".localized() }
    private var calendarLabel: String { "event_detail::share::field::calendar".localized() }
    private var todoText: String { "calendar::event_time::todo".localized() }

    private func fullModel() -> EventDetailShareModel {
        return EventDetailShareModel(
            name: "약먹기",
            isTodo: true,
            timeText: "2026.08.15 (금) 09:00 ~ 10:00",
            repeatText: "매일",
            tagLine: .eventTag("건강"),
            placeName: "강남약국",
            url: "https://example.com",
            memo: "식후 30분"
        )
    }

    @Test func builder_rendersNameThenLabeledFieldsInOrder() {
        // given
        let model = self.fullModel()

        // when
        let result = self.builder.build(model)

        // then
        let expected = [
            "(\(self.todoText)) 약먹기",
            "\(self.label("time")): 2026.08.15 (금) 09:00 ~ 10:00",
            "\(self.label("repeating")): 매일",
            "\(self.tagLabel): 건강",
            "\(self.label("place")): 강남약국",
            "\(self.label("url")): https://example.com",
            "\(self.label("memo")): 식후 30분"
        ].joined(separator: "\n")
        #expect(result == expected)
    }

    @Test func builder_whenTagLineIsGoogleCalendar_rendersServiceNamePrefixedCalendarLabel() {
        // given
        let model = EventDetailShareModel(name: "이름", tagLine: .googleCalendar("업무"))

        // when
        let result = self.builder.build(model)

        // then
        let serviceName = "event_setting::external_calendar::google::serviceName".localized()
        #expect(self.calendarLabel != self.tagLabel)
        #expect(result == "이름\n\(self.calendarLabel): \(serviceName) - 업무")
    }

    @Test func builder_whenTagLineIsAppleCalendar_rendersServiceNamePrefixedCalendarLabel() {
        // given
        let model = EventDetailShareModel(name: "이름", tagLine: .appleCalendar("업무"))

        // when
        let result = self.builder.build(model)

        // then
        let serviceName = "event_setting::external_calendar::apple::serviceName".localized()
        #expect(self.calendarLabel != self.tagLabel)
        #expect(result == "이름\n\(self.calendarLabel): \(serviceName) - 업무")
    }

    @Test func builder_googleAndAppleCalendarTagLines_produceDifferentServiceNamePrefixes() {
        // given
        let googleModel = EventDetailShareModel(name: "이름", tagLine: .googleCalendar("업무"))
        let appleModel = EventDetailShareModel(name: "이름", tagLine: .appleCalendar("업무"))

        // when
        let googleResult = self.builder.build(googleModel)
        let appleResult = self.builder.build(appleModel)

        // then
        #expect(googleResult != appleResult)
    }

    @Test func builder_whenFieldIsNil_omitsThatLine() {
        // given
        let model = EventDetailShareModel(
            name: "이름", timeText: "시간", repeatText: nil,
            tagLine: nil, placeName: nil, url: nil, memo: nil
        )

        // when
        let result = self.builder.build(model)

        // then
        #expect(result == "이름\n\(self.label("time")): 시간")
    }

    @Test func builder_whenEventIsNotTodo_hasNoTodoPrefix() {
        // given
        let model = EventDetailShareModel(name: "이름", isTodo: false, timeText: "시간")

        // when
        let result = self.builder.build(model)

        // then
        #expect(result.components(separatedBy: "\n").first == "이름")
    }

    @Test func builder_whenOnlyNameExists_rendersNameAlone() {
        // given
        let model = EventDetailShareModel(name: "이름")

        // when
        let result = self.builder.build(model)

        // then
        #expect(result == "이름")
    }

    @Test func builder_whenMemoHasMultipleLines_keepsThemAfterLabel() {
        // given
        let model = EventDetailShareModel(name: "이름", memo: "첫째 줄\n둘째 줄")

        // when
        let result = self.builder.build(model)

        // then
        #expect(result == "이름\n\(self.label("memo")): 첫째 줄\n둘째 줄")
    }

    @Test func builder_hasNoBlankLineBetweenFields() {
        // given
        let model = self.fullModel()

        // when
        let result = self.builder.build(model)

        // then
        #expect(!result.contains("\n\n"))
        #expect(!result.hasSuffix("\n"))
    }
}


// MARK: - timeText(from:) at

extension EventDetailShareTextBuilderTests {

    @Test func timeText_at_joinsDayAndTime() {
        // given
        let time = SelectTimeText(Date().timeIntervalSince1970, self.timeZone)
        let selectedTime = SelectedTime.at(time)

        // when
        let result = self.builder.timeText(from: selectedTime)

        // then
        #expect(time.year == nil)
        let expected = [time.day, time.time].compactMap { $0 }.joined(separator: " ")
        #expect(result == expected)
    }

    @Test func timeText_at_whenNotCurrentYear_includesYear() {
        // given
        let pastDate = Date().addingTimeInterval(-20 * 365 * 24 * 3600)
        let time = SelectTimeText(pastDate.timeIntervalSince1970, self.timeZone)
        let selectedTime = SelectedTime.at(time)

        // when
        let result = self.builder.timeText(from: selectedTime)

        // then
        let year = try? #require(time.year)
        #expect(year != nil)
        #expect(result.hasPrefix(year ?? ""))
        let expected = [time.year, time.day, time.time].compactMap { $0 }.joined(separator: " ")
        #expect(result == expected)
    }
}


// MARK: - timeText(from:) period

extension EventDetailShareTextBuilderTests {

    @Test func timeText_period_sameDay_showsDayOnceWithTildeTimes() throws {
        // given
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.timeZone
        let startDate = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()))
        let endDate = try #require(calendar.date(byAdding: .hour, value: 1, to: startDate))
        let start = SelectTimeText(startDate.timeIntervalSince1970, self.timeZone)
        let end = SelectTimeText(endDate.timeIntervalSince1970, self.timeZone)
        let selectedTime = SelectedTime.period(start, end)

        // when
        let result = self.builder.timeText(from: selectedTime)

        // then
        #expect(start.day == end.day)
        let components = result.components(separatedBy: " ~ ")
        #expect(components.count == 2)
        #expect(components[0].contains(start.day))
        #expect(components[0].hasSuffix(start.time ?? "__missing__"))
        #expect(components[1] == (end.time ?? ""))
        #expect(result.components(separatedBy: start.day).count - 1 == 1)
    }

    @Test func timeText_period_differentDays_showsBothSides() throws {
        // given
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.timeZone
        let startDate = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: startDate))
        let endDate = try #require(calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nextDay))
        let start = SelectTimeText(startDate.timeIntervalSince1970, self.timeZone)
        let end = SelectTimeText(endDate.timeIntervalSince1970, self.timeZone)
        let selectedTime = SelectedTime.period(start, end)

        // when
        let result = self.builder.timeText(from: selectedTime)

        // then
        #expect(start.day != end.day)
        let components = result.components(separatedBy: " ~ ")
        #expect(components.count == 2)
        #expect(components[0].contains(start.day))
        #expect(components[0].hasSuffix(start.time ?? "__missing__"))
        #expect(components[1].contains(end.day))
        #expect(components[1].hasSuffix(end.time ?? "__missing__"))
    }
}


// MARK: - timeText(from:) allday

extension EventDetailShareTextBuilderTests {

    @Test func timeText_singleAllDay_appendsAllDayText() {
        // given
        let time = SelectTimeText(Date().timeIntervalSince1970, self.timeZone, withoutTime: true)
        let selectedTime = SelectedTime.singleAllDay(time)

        // when
        let result = self.builder.timeText(from: selectedTime)

        // then
        let allDayText = "calendar::event_time::allday".localized()
        #expect(result.hasSuffix(allDayText))
        #expect(result.contains(time.day))
    }

    @Test func timeText_alldayPeriod_joinsBothDaysWithAllDayText() throws {
        // given
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = self.timeZone
        let startDate = Date()
        let endDate = try #require(calendar.date(byAdding: .day, value: 2, to: startDate))
        let start = SelectTimeText(startDate.timeIntervalSince1970, self.timeZone, withoutTime: true)
        let end = SelectTimeText(endDate.timeIntervalSince1970, self.timeZone, withoutTime: true)
        let selectedTime = SelectedTime.alldayPeriod(start, end)

        // when
        let result = self.builder.timeText(from: selectedTime)

        // then
        let allDayText = "calendar::event_time::allday".localized()
        #expect(result.hasSuffix(allDayText))
        #expect(result.contains(start.day))
        #expect(result.contains(end.day))
        let components = result.components(separatedBy: " ~ ")
        #expect(components.count == 2)
    }
}
