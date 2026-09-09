//
//  TodayAndNextWidgetViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation


// MARK: - TodayAndNextWidgetViewModel

public struct TodayAndNextWidgetViewModel {
    public var left: PageModel
    public var right: PageModel
    public var refreshAfter: TimeInterval?
    public let defaultTagColorSetting: DefaultEventTagColorSetting
    public let customTagMap: [String: any EventTag]
    public var googleCalendarColors: GoogleCalendar.Colors = .init(ownerId: "", calendars: [:], events: [:])
    public var googleCalendarTags: [String: GoogleCalendar.Tag] = [:]
    public var appleCalendarTags: [String: AppleCalendar.Tag] = [:]
    public var widgetSetting = WidgetAppearanceSettings()

    public init(
        left: PageModel,
        right: PageModel,
        refreshAfter: TimeInterval? = nil,
        defaultTagColorSetting: DefaultEventTagColorSetting,
        customTagMap: [String: any EventTag],
        googleCalendarColors: GoogleCalendar.Colors = .init(ownerId: "", calendars: [:], events: [:]),
        googleCalendarTags: [String: GoogleCalendar.Tag] = [:],
        appleCalendarTags: [String: AppleCalendar.Tag] = [:],
        widgetSetting: WidgetAppearanceSettings = WidgetAppearanceSettings()
    ) {
        self.left = left
        self.right = right
        self.refreshAfter = refreshAfter
        self.defaultTagColorSetting = defaultTagColorSetting
        self.customTagMap = customTagMap
        self.googleCalendarColors = googleCalendarColors
        self.googleCalendarTags = googleCalendarTags
        self.appleCalendarTags = appleCalendarTags
        self.widgetSetting = widgetSetting
    }

    public static func sample() -> TodayAndNextWidgetViewModel {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let today = TodayAndNextWidgetViewModel.TodayModel(
            weekOfDay: now.text("date_form.EEEE".localized()),
            day: calendar.component(.day, from: now)
        )
        let check = TodoEventCellViewModel(
            currentTodo: TodoCalendarEvent(
                current: TodoEvent(uuid: "check", name: "widget.events.sample::check_mailbox".localized()), isForemost: false
            )
        )
        let runningEvent = ScheduleEventCellViewModel("running", name: "\("widget.events.sample::running".localized())")
            |> \.periodText .~ .doubleText(.init(text: "08:00"), .init(text: "10:00"))
        
        let todayEvents = [
            TodayAndNextWidgetViewModel.EventModel(cvm: check),
            TodayAndNextWidgetViewModel.EventModel(cvm: runningEvent)
        ]
        
        let tomorrow = TodayAndNextWidgetViewModel.DateModel(dateText: "tomorrow".localized())
        
        let movingEvent = ScheduleEventCellViewModel("moving", name: "widget.events.sample::moving".localized())
            |> \.periodText .~ .singleText(.init(text: "calendar::event_time::allday".localized()))
            |> \.eventTimeRawValue .~ .allDay(0..<10, secondsFromGMT: 0)
            |> \.colorSource .~ EventTagId.custom("moving")

        let depositEvent = TodoEventCellViewModel("deposit", name: "widget.events.sample::deposit_remain".localized())
            |> \.periodText .~ .singleText(.init(text: "11:00"))
            |> \.colorSource .~ EventTagId.custom("moving")
        
        let lunchEvent = ScheduleEventCellViewModel("lunch", name: "widget.events.sample::luch_appointment".localized())
            |> \.periodText .~ .singleText(.init(text: "13:00"))
        let meeting = ScheduleEventCellViewModel("meeting", name: "widget.events.sample::meeting".localized())
            |> \.periodText .~ .doubleText(.init(text: "16:00"), .init(text: "17:00"))
        let tomorrowEvents = [
            TodayAndNextWidgetViewModel.EventModel(cvm: movingEvent),
            TodayAndNextWidgetViewModel.EventModel(cvm: depositEvent),
            TodayAndNextWidgetViewModel.EventModel(cvm: lunchEvent),
            TodayAndNextWidgetViewModel.EventModel(cvm: meeting)
        ]
        
        let defaultTagColorSetting = DefaultEventTagColorSetting(
            holiday: "#D6236A", default: "#088CDA"
        )
        
        let left = PageModel(rows: [today] + todayEvents)
        let right = PageModel(rows: [tomorrow] + tomorrowEvents)
        return .init(
            left: left, right: right,
            defaultTagColorSetting: defaultTagColorSetting,
            customTagMap: [
                "moving": CustomEventTag(name: "moving", colorHex: "#FFA02E")
            ]
        )
    }
}

// MARK: - rows

public protocol TodayAndNextWidgetViewModelRow: Identifiable {
    associatedtype ID = String
    var rowWeight: Float { get }
    var id: String { get }
}

extension TodayAndNextWidgetViewModel {
    
    public struct TodayModel: TodayAndNextWidgetViewModelRow {
        
        public let weekOfDay: String
        public let day: Int
        public var timeZonetext: String?
        public let rowWeight: Float = 2.0
        
        public var id: String { "\(self.day)" }

        public init(weekOfDay: String, day: Int, timeZonetext: String? = nil) {
            self.weekOfDay = weekOfDay
            self.day = day
            self.timeZonetext = timeZonetext
        }
    }
    
    public struct DateModel: TodayAndNextWidgetViewModelRow {
        public let dateText: String
        public let rowWeight: Float = 2/3
        
        public var id: String { self.dateText }

        public init(dateText: String) {
            self.dateText = dateText
        }
    }
    
    public struct EventModel: TodayAndNextWidgetViewModelRow {
        public let cvm: any EventCellViewModel
        public var rowWeight: Float {
            switch cvm {
            case let todo as TodoEventCellViewModel where todo.eventTimeRawValue == nil:
                return 2/3
            default:
                return self.cvm.isAlldayEvent ? 2/3 : 1
            }
        }
        
        public var id: String { self.cvm.eventIdentifier }

        public init(cvm: any EventCellViewModel) {
            self.cvm = cvm
        }
    }
    
    public struct MultipleEventsSummaryModel: TodayAndNextWidgetViewModelRow {
        
        public let tags: [EventTagId]
        public var totalCount: Int { self.tags.count }
        public let todoCount: Int
        public var nonTodoEventCount: Int { totalCount - todoCount }
        public let rowWeight: Float = 2/3
        
        public let id: String
        
        public init(_ rows: [EventModel]) {
            
            let cvms = rows.map { $0.cvm }
            self.id = UUID().uuidString
            
            self.tags = cvms.map { ($0.colorSource as? EventTagId) ?? .default }
            self.todoCount = cvms.filter { $0 is TodoEventCellViewModel }.count
        }
    }
    
    public struct UncompletedTodayTodoSummaryModel: TodayAndNextWidgetViewModelRow {
        
        public let firstTodoName: String
        public let andOtherTodosCount: Int
        public let id: String
        
        public var rowWeight: Float { 2/3 }
        
        public init?(_ todos: [TodoCalendarEvent]) {
            guard !todos.isEmpty else { return nil }
            self.id = UUID().uuidString
            self.firstTodoName = todos[0].name
            self.andOtherTodosCount = todos.count-1
        }
    }
}

// MARK: - page model

extension TodayAndNextWidgetViewModel {
    
    public struct PageModel {
        public var rows: [any TodayAndNextWidgetViewModelRow] = []

        public init(rows: [any TodayAndNextWidgetViewModelRow] = []) {
            self.rows = rows
        }
        
        public func remainWeight(_ max: Float) -> Float {
            return max - rows.reduce(0, { $0 + $1.rowWeight })
        }
    }
}

/**
 좌측: 좌측 최상단 dayModel 채우고
 1. 잔여 공간에 current todo 있는만큼 채우고
 2. 그 잔여 공간에 오늘 allday 이벤트 채울수 있는만큼 채우고
 3. 1 + 2 이벤트 총합이 잔여공간을 초과하는 경우에는 마지막행 요약형으로 변환
 4. 이후 좌측 잔여 공간에 오늘 이벤트 채움, 공간 모자르면 오른쪽으로 넘어가고 / 남아도 별거 안함
 
 우측: 전체가 가용 영역
 1. 오늘 이벤트 남은거 있으면 우선적으로 채우고
 2. 오늘 이벤트 공간 모자르면 -> 마지막 행은 요약형으로 변환
 3. 잔여 공간 2개 이상일떄 우선적으로 내일 이벤트 채움 -> 내일 이벤트의 경우 요약형 없음
 4. 이후에도 공간이 2개 이상 남으면 그 다음 일자 이벤트를 채움
 5. 공간 남으면 계속 체우고, 공간이 모질라면 마지막 날짜의 이벤트는 축약형으로 전환
 */
