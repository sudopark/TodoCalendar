//
//  WeekEventsWidgetViewModelProviderTests.swift
//  TodoCalendarAppWidgetTests
//
//  Created by sudo.park on 7/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation
import UnitTestHelpKit
import TestDoubles


class WeekEventsWidgetViewModelProviderTests: BaseTestCase {
    
    private var dummyDate: Date {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ kst
        return calendar.dateBySetting(from: Date()) {
            $0.year = 2024; $0.month = 6; $0.day = 12; $0.hour = 0
        }!
    }
    
    private var kst: TimeZone {
        return TimeZone(abbreviation: "KST")!
    }
    
    private func makeProvider(
        showWeekDayHeaderStyle: Bool? = nil,
        customStyles: [String: WeekEventsStyleSetting] = [:],
        defaultStyleBackground: WidgetAppearanceSettings.Background? = nil,
        customStyleBackgrounds: [String: WidgetAppearanceSettings.Background] = [:]
    ) -> WeekEventsWidgetViewModelProvider {
        let calendarUsecase = CalendarUsecaseImple(
            calendarSettingUsecase: StubCalendarSettingUsecase(),
            holidayUsecase: StubHolidayUsecase()
        )
        let fetchUsecase = PrivateEventsFetchUsecase()
        let calendarSettingRepository = StubCalendarSettingRepository()
        calendarSettingRepository.saveTimeZone(kst)
        
        let defaultId = WidgetStyleId(variant: .oneWeekEvents, style: .default)
        let hasDefault = showWeekDayHeaderStyle != nil || defaultStyleBackground != nil
        let defaultStyle = hasDefault
        ? [
            defaultId: WidgetStyle(
                id: defaultId, name: nil,
                setting: WeekEventsStyleSetting.initial |> \.showWeekDayHeader .~ (showWeekDayHeaderStyle ?? true),
                background: defaultStyleBackground
            )
        ]
        : [:]
        let customKeys = Set(customStyles.keys).union(customStyleBackgrounds.keys)
        let customs = customKeys.reduce(
            into: [WidgetStyleId: WidgetStyle]()
        ) { acc, key in
            let id = WidgetStyleId(variant: .oneWeekEvents, style: .custom(id: key))
            acc[id] = WidgetStyle(
                id: id, name: nil,
                setting: customStyles[key] ?? WeekEventsStyleSetting.initial,
                background: customStyleBackgrounds[key]
            )
        }
        
        return WeekEventsWidgetViewModelProvider(
            calendarUsecase: calendarUsecase,
            eventFetchUsecase: fetchUsecase,
            settingRepository: calendarSettingRepository,
            appSettingRepository: StubAppSettingRepository(),
            styleRepository: StubWidgetStyleRepository(
                styles: defaultStyle.merging(customs) { _, custom in custom }
            )
        )
    }
}


// MARK: - 스타일 해석

extension WeekEventsWidgetViewModelProviderTests {
    
    func testProvider_whenStyleTurnsOffWeekDayHeader_applyItToViewModel() async throws {
        // given
        let provider = self.makeProvider(showWeekDayHeaderStyle: false)
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1)
        )
        
        // then
        XCTAssertEqual(model.showsWeekDayHeader, false)
    }
    
    func testProvider_whenInstanceSelectsCustomStyle_applyThatStyle() async throws {
        // given
        let provider = self.makeProvider(
            showWeekDayHeaderStyle: true,
            customStyles: [
                "c1": WeekEventsStyleSetting.initial |> \.showWeekDayHeader .~ false
            ]
        )
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1), style: .custom(id: "c1")
        )
        
        // then
        XCTAssertEqual(model.showsWeekDayHeader, false)
    }
    
    /// 7변형이 좌표 하나를 공유하므로 어느 범위로 조회해도 같은 스타일이 붙는다.
    func testProvider_whateverRangeGiven_applySameSharedStyle() async throws {
        // given
        let provider = self.makeProvider(showWeekDayHeaderStyle: false)
        
        // when
        let thisWeek = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1)
        )
        let lastMonth = try await provider.getWeekEventsModel(
            from: dummyDate, range: .wholeMonth(.previous)
        )
        
        // then
        XCTAssertEqual(thisWeek.showsWeekDayHeader, false)
        XCTAssertEqual(lastMonth.showsWeekDayHeader, false)
    }
    
    func testProvider_whenSelectedCustomStyleRemoved_fallbackToVariantDefaultStyle() async throws {
        // given
        let provider = self.makeProvider(showWeekDayHeaderStyle: false)
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1), style: .custom(id: "removed")
        )
        
        // then
        XCTAssertEqual(model.showsWeekDayHeader, false)
    }
    
    func testProvider_whenStyleHasBackground_appliesItToWidgetSetting() async throws {
        // given
        let provider = self.makeProvider(
            defaultStyleBackground: .custom(hex: "#ffffff"),
            customStyleBackgrounds: ["c1": .custom(hex: "#101820")]
        )

        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1), style: .custom(id: "c1")
        )

        // then
        XCTAssertEqual(model.widgetSetting.background, .custom(hex: "#101820"))
    }

    /// 폴백이 스타일 단위라, 고른 스타일이 색을 안 걸었으면 기본 스타일 색을 빌려오지 않는다.
    func testProvider_whenSelectedStyleHasNoBackground_useGlobalNotDefaultStyle() async throws {
        // given
        let provider = self.makeProvider(
            customStyles: ["c1": WeekEventsStyleSetting.initial],
            defaultStyleBackground: .custom(hex: "#ffffff")
        )

        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1), style: .custom(id: "c1")
        )

        // then
        XCTAssertNotEqual(model.widgetSetting.background, .custom(hex: "#ffffff"))
    }

    func testProvider_whenNoStyleSaved_useInitialSetting() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1)
        )
        
        // then
        XCTAssertEqual(model.style, WeekEventsStyleSetting.initial)
    }
}


extension WeekEventsWidgetViewModelProviderTests{
    
    // load this week
    func testProvider_viewModelForThisWeek() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 1)
        )
        
        // then
        XCTAssertEqual(model.targetMonthText, "JUNE")
        XCTAssertEqual(model.targetDayIndetifier, "2024-6-12")
        let days = model.weeks.map { w in w.days.map { $0.day } }
        let accentDays = model.weeks.map { w in w.days.map { $0.accentDay }}
        let eventIds = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.eventId } }
        }
        let daySequences = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.daysSequence } }
        }
        XCTAssertEqual(days, [[9, 10, 11, 12, 13, 14, 15]])
        XCTAssertEqual(accentDays, [[.sunday, nil, nil, nil, nil, nil, .saturday]])
        XCTAssertEqual(eventIds, [
            "2024-6-9-2024-6-15": [["todo1", "schedule-1"], ["todo2"]]
        ])
        XCTAssertEqual(daySequences, [
            "2024-6-9-2024-6-15": [[(1...1), (7...7)], [7...7]]
        ])
    }
    
    // load this and next week
    func testProvider_viewModelForThisWeekAndNextWeek() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 2)
        )
        
        // then
        XCTAssertEqual(model.targetMonthText, "JUNE")
        XCTAssertEqual(model.targetDayIndetifier, "2024-6-12")
        let days = model.weeks.map { w in w.days.map { $0.day } }
        let accentDays = model.weeks.map { w in w.days.map { $0.accentDay }}
        let eventIds = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.eventId } }
        }
        let daySequences = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.daysSequence } }
        }
        XCTAssertEqual(days, [
            [9, 10, 11, 12, 13, 14, 15],
            [16, 17, 18, 19, 20, 21, 22]
        ])
        XCTAssertEqual(accentDays, [
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, .holiday, nil, nil, .saturday]
        ])
        XCTAssertEqual(eventIds, [
            "2024-6-9-2024-6-15": [["todo1"]],
            "2024-6-16-2024-6-22": [["2024-06-19-dummy_holiday", "schedule-1"], ["todo2"]]
        ])
        XCTAssertEqual(daySequences, [
            "2024-6-9-2024-6-15": [[(1...1)]],
            "2024-6-16-2024-6-22": [[(4...4), (7...7)], [7...7]]
        ])
    }
    
    // load this and next 2 weeks
    func testProvider_viewModelForThisWeekAndNext2Week() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 3)
        )
        
        // then
        XCTAssertEqual(model.targetMonthText, "JUNE")
        XCTAssertEqual(model.targetDayIndetifier, "2024-6-12")
        let days = model.weeks.map { w in w.days.map { $0.day } }
        let accentDays = model.weeks.map { w in w.days.map { $0.accentDay }}
        let eventIds = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.eventId } }
        }
        let daySequences = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.daysSequence } }
        }
        XCTAssertEqual(days, [
            [9, 10, 11, 12, 13, 14, 15],
            [16, 17, 18, 19, 20, 21, 22],
            [23, 24, 25, 26, 27, 28, 29],
        ])
        XCTAssertEqual(accentDays, [
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, .holiday, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
        ])
        XCTAssertEqual(eventIds, [
            "2024-6-9-2024-6-15": [["todo1"]],
            "2024-6-16-2024-6-22": [["2024-06-19-dummy_holiday"]],
            "2024-6-23-2024-6-29": [["schedule-1"], ["todo2"]]
        ])
        XCTAssertEqual(daySequences, [
            "2024-6-9-2024-6-15": [[(1...1)]],
            "2024-6-16-2024-6-22": [[(4...4)]],
            "2024-6-23-2024-6-29": [[7...7], [7...7]]
        ])
    }
    
    // load this and next 3 weeks
    func testProvider_viewModelForThisWeekAndNext3Week() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .weeks(count: 4)
        )
        
        // then
        XCTAssertEqual(model.targetMonthText, "JUNE")
        XCTAssertEqual(model.targetDayIndetifier, "2024-6-12")
        let days = model.weeks.map { w in w.days.map { $0.day } }
        let accentDays = model.weeks.map { w in w.days.map { $0.accentDay }}
        let eventIds = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.eventId } }
        }
        let daySequences = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.daysSequence } }
        }
        XCTAssertEqual(days, [
            [9, 10, 11, 12, 13, 14, 15],
            [16, 17, 18, 19, 20, 21, 22],
            [23, 24, 25, 26, 27, 28, 29],
            [30, 1, 2, 3, 4, 5, 6],
        ])
        XCTAssertEqual(accentDays, [
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, .holiday, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
        ])
        XCTAssertEqual(eventIds, [
            "2024-6-9-2024-6-15": [["todo1"]],
            "2024-6-16-2024-6-22": [["2024-06-19-dummy_holiday"]],
            "2024-6-23-2024-6-29": [],
            "2024-6-30-2024-7-6": [["schedule-1"], ["todo2"]]
        ])
        XCTAssertEqual(daySequences, [
            "2024-6-9-2024-6-15": [[(1...1)]],
            "2024-6-16-2024-6-22": [[(4...4)]],
            "2024-6-23-2024-6-29": [],
            "2024-6-30-2024-7-6": [[7...7], [7...7]]
        ])
    }
    
    // load this whole month
    func testProvider_viewModelForThisMonth() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .wholeMonth(.current)
        )
        
        // then
        XCTAssertEqual(model.targetMonthText, "JUNE")
        XCTAssertEqual(model.targetDayIndetifier, "2024-6-12")
        let days = model.weeks.map { w in w.days.map { $0.day } }
        let accentDays = model.weeks.map { w in w.days.map { $0.accentDay }}
        let eventIds = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.eventId } }
        }
        let daySequences = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.daysSequence } }
        }
        XCTAssertEqual(days, [
            [26, 27, 28, 29, 30, 31, 1],
            [2, 3, 4, 5, 6, 7, 8],
            [9, 10, 11, 12, 13, 14, 15],
            [16, 17, 18, 19, 20, 21, 22],
            [23, 24, 25, 26, 27, 28, 29],
            [30, 1, 2, 3, 4, 5, 6],
        ])
        XCTAssertEqual(accentDays, [
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, .holiday, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
        ])
        XCTAssertEqual(eventIds, [
            "2024-5-26-2024-6-1": [["todo1"]],
            "2024-6-2-2024-6-8": [],
            "2024-6-9-2024-6-15": [],
            "2024-6-16-2024-6-22": [["2024-06-19-dummy_holiday"]],
            "2024-6-23-2024-6-29": [],
            "2024-6-30-2024-7-6": [["schedule-1"], ["todo2"]]
        ])
        XCTAssertEqual(daySequences, [
            "2024-5-26-2024-6-1": [[(1...1)]],
            "2024-6-2-2024-6-8": [],
            "2024-6-9-2024-6-15": [],
            "2024-6-16-2024-6-22": [[(4...4)]],
            "2024-6-23-2024-6-29": [],
            "2024-6-30-2024-7-6": [[7...7], [7...7]]
        ])
    }
    
    // load previous whole month
    func testProvider_viewModelForPreviousMonth() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .wholeMonth(.previous)
        )
        
        // then
        XCTAssertEqual(model.targetMonthText, "MAY")
        XCTAssertEqual(model.targetDayIndetifier, "2024-6-12")
        let days = model.weeks.map { w in w.days.map { $0.day } }
        let accentDays = model.weeks.map { w in w.days.map { $0.accentDay }}
        let eventIds = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.eventId } }
        }
        let daySequences = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.daysSequence } }
        }
        XCTAssertEqual(days, [
            [28, 29, 30, 1, 2, 3, 4],
            [5, 6, 7, 8, 9, 10, 11],
            [12, 13, 14, 15, 16, 17, 18],
            [19, 20, 21, 22, 23, 24, 25],
            [26, 27, 28, 29, 30, 31, 1],
        ])
        XCTAssertEqual(accentDays, [
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
        ])
        XCTAssertEqual(eventIds, [
            "2024-4-28-2024-5-4": [["todo1"]],
            "2024-5-5-2024-5-11": [],
            "2024-5-12-2024-5-18": [],
            "2024-5-19-2024-5-25": [],
            "2024-5-26-2024-6-1": [["schedule-1"], ["todo2"]]
        ])
        XCTAssertEqual(daySequences, [
            "2024-4-28-2024-5-4": [[(1...1)]],
            "2024-5-5-2024-5-11": [],
            "2024-5-12-2024-5-18": [],
            "2024-5-19-2024-5-25": [],
            "2024-5-26-2024-6-1": [[7...7], [7...7]]
        ])
    }
    
    // load next whole month
    func testProvider_viewModelForNextMonth() async throws {
        // given
        let provider = self.makeProvider()
        
        // when
        let model = try await provider.getWeekEventsModel(
            from: dummyDate, range: .wholeMonth(.next)
        )
        
        // then
        XCTAssertEqual(model.targetMonthText, "JULY")
        XCTAssertEqual(model.targetDayIndetifier, "2024-6-12")
        let days = model.weeks.map { w in w.days.map { $0.day } }
        let accentDays = model.weeks.map { w in w.days.map { $0.accentDay }}
        let eventIds = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.eventId } }
        }
        let daySequences = model.eventStackModelMap.mapValues { stack in
            stack.linesStack.map { ls in ls.map { $0.daysSequence } }
        }
        XCTAssertEqual(days, [
            [30, 1, 2, 3, 4, 5, 6],
            [7, 8, 9, 10, 11, 12, 13],
            [14, 15, 16, 17, 18, 19, 20],
            [21, 22, 23, 24, 25, 26, 27],
            [28, 29, 30, 31, 1, 2, 3]
        ])
        XCTAssertEqual(accentDays, [
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
            [.sunday, nil, nil, nil, nil, nil, .saturday],
        ])
        XCTAssertEqual(eventIds, [
            "2024-6-30-2024-7-6": [["todo1"]],
            "2024-7-7-2024-7-13": [],
            "2024-7-14-2024-7-20": [],
            "2024-7-21-2024-7-27": [],
            "2024-7-28-2024-8-3": [["schedule-1"], ["todo2"]]
        ])
        XCTAssertEqual(daySequences, [
            "2024-6-30-2024-7-6": [[(1...1)]],
            "2024-7-7-2024-7-13": [],
            "2024-7-14-2024-7-20": [],
            "2024-7-21-2024-7-27": [],
            "2024-7-28-2024-8-3": [[7...7], [7...7]]
        ])
    }
}


private final class PrivateEventsFetchUsecase: StubCalendarEventsFetchUescase {
    
    override func fetchEvents(in range: Range<TimeInterval>, _ timeZone: TimeZone, withoutOffTagIds: Bool) async throws -> CalendarEvents {
        let events = try await super.fetchEvents(in: range, timeZone, withoutOffTagIds: withoutOffTagIds)
        let eventsWithoutHoliday = events.eventWithTimes.filter { !($0 is HolidayCalendarEvent) }
        let dummyHoliday = Holiday(uuid: "2024-06-19-dummy_holiday", dateString: "2024-06-19", name: "dummy_holiday")
        let holidayEvent = HolidayCalendarEvent(dummyHoliday, in: timeZone)!
        let newEvents = eventsWithoutHoliday + [holidayEvent]
        return events |> \.eventWithTimes .~ newEvents
    }
}
