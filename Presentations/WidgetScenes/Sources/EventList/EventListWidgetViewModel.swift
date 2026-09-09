//
//  EventListWidgetViewModel.swift
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
import CommonPresentation
import CalendarPresentation


// MARK: - EventListWidgetViewModel

public enum EventListWidgetSize: Sendable {
    case small
    case medium
    case large
}

public struct EventListWidgetViewModel {
    
    public struct SectionModel {
        public var sectionTitle: String?
        public var events: [any EventCellViewModel]
        public var shouldAccentTitle: Bool = false
        public var isCurrentDay = false
        public var isCurrentTodos = false
        
        public init(
            title: String?,
            events: [any EventCellViewModel],
            shouldAccentTitle: Bool = false,
            isCurrentDay: Bool = false,
            isCurrentTodos: Bool = false
        ) {
            self.sectionTitle = title
            self.events = events
            self.shouldAccentTitle = shouldAccentTitle
            self.isCurrentDay = isCurrentDay
            self.isCurrentTodos = isCurrentTodos
        }
    }
    public struct PageModel {
        public var sections: [SectionModel]
        public var needBottomSpace: Bool = false

        public init(sections: [SectionModel], needBottomSpace: Bool = false) {
            self.sections = sections
            self.needBottomSpace = needBottomSpace
        }
        
        public mutating func append(section: SectionModel) {
            self.sections.append(section)
        }
        
        public mutating func append(event: any EventCellViewModel) {
            guard !self.sections.isEmpty else { return }
            self.sections[self.sections.count-1].events.append(event)
        }
    }
    
    public var pages: [PageModel]
    public let defaultTagColorSetting: DefaultEventTagColorSetting
    public let customTagMap: [String: any EventTag]
    public var googleCalendarColors: GoogleCalendar.Colors = .init(ownerId: "", calendars: [:], events: [:])
    public var googleCalendarTags: [String: GoogleCalendar.Tag] = [:]
    public var appleCalendarTags: [String: AppleCalendar.Tag] = [:]
    public var widgetSetting: WidgetAppearanceSettings = .init()

    public init(
        pages: [PageModel],
        defaultTagColorSetting: DefaultEventTagColorSetting,
        customTagMap: [String: any EventTag],
        googleCalendarColors: GoogleCalendar.Colors = .init(ownerId: "", calendars: [:], events: [:]),
        googleCalendarTags: [String: GoogleCalendar.Tag] = [:],
        appleCalendarTags: [String: AppleCalendar.Tag] = [:],
        widgetSetting: WidgetAppearanceSettings = .init()
    ) {
        self.pages = pages
        self.defaultTagColorSetting = defaultTagColorSetting
        self.customTagMap = customTagMap
        self.googleCalendarColors = googleCalendarColors
        self.googleCalendarTags = googleCalendarTags
        self.appleCalendarTags = appleCalendarTags
        self.widgetSetting = widgetSetting
    }

    public static func sample(size: EventListWidgetSize) -> EventListWidgetViewModel {
        
        let runningEvent = ScheduleEventCellViewModel("running", name: "🏃‍♂️ \("widget.events.sample::running".localized())")
            |> \.periodText .~ .singleText(.init(text: "8:00"))
        
        let lunchEvent = ScheduleEventCellViewModel("lunch", name: "🍔 \("widget.events.sample::luch".localized())")
            |> \.periodText .~ .singleText(.init(text: "1:00"))
        
        let callTodoEvent = TodoEventCellViewModel("call", name: "📞 \("Call Sara".localized())")
            |> \.periodText .~ .singleText(.init(text: "3:00"))
        
        let surfingEvent = ScheduleEventCellViewModel("surfing", name: "🏄‍♂️ \("widget.events.sample::surfing".localized())")
            |> \.periodText .~ .singleText(.init(text: "calendar::event_time::allday".localized()))
        
        let meeting = ScheduleEventCellViewModel("meeting", name: "widget.events.sample::meeting".localized())
        |> \.periodText .~ .singleText(.init(text: "10:00"))
        
        let golf = ScheduleEventCellViewModel("golf", name: "widget.weeks.sample::golf".localized())
        |> \.periodText .~ .singleText(.init(text: "calendar::event_time::allday".localized()))
        
        let recycle = TodoEventCellViewModel("recycle", name: "widget.events.sample::recycle".localized())
        |> \.periodText .~ .singleText(.init(text: "8:00"))
        
        let takeMedicine = TodoEventCellViewModel("take", name: "widget.events.sample::take_medicine".localized())
        |> \.periodText .~ .singleText(.init(text: "9:00"))
        
        let watering = TodoEventCellViewModel("water", name: "widget.events.sample::watering".localized())
        |> \.periodText .~ .singleText(.init(text: "12:00"))
        
        let holiday = HolidayEventCellViewModel(
            .init(.init(uuid: "hd", dateString: "2023-10-10", name: "widget.weeks.sample::holiday".localized()), in: .current)!
        )
        
        let defaultTagColorSetting = DefaultEventTagColorSetting(
            holiday: "#D6236A", default: "#088CDA"
        )
        
        switch size {
        case .small:
            let june3 = SectionModel(
                title: "widget.events.sample::june3".localized(),
                events: [ lunchEvent, callTodoEvent ],
                shouldAccentTitle: true
            )
            
            let july = SectionModel(title: "widget.events.sample::july16".localized(), events: [
                runningEvent, surfingEvent
            ])
            return .init(
                pages: [
                    .init(sections: [june3, july])
                ],
                defaultTagColorSetting: defaultTagColorSetting, customTagMap: [:]
            )
            
        case .medium:
            let june3 = SectionModel(
                title: "widget.events.sample::june3".localized(),
                events: [ lunchEvent, callTodoEvent ],
                shouldAccentTitle: true
            )
            
            let july = SectionModel(title: "widget.events.sample::july16".localized(), events: [
                runningEvent, surfingEvent
            ])
            let july21 = SectionModel(
                title: "widget.events.sample::july21".localized(), events: [
                    meeting
                ]
            )
            let oct = SectionModel(
                title: "widget.events.sample::oct10".localized(), events: [
                    holiday
                ]
            )
            return .init(
                pages: [
                    .init(sections: [june3, july]),
                    .init(sections: [july21, oct], needBottomSpace: true)
                ],
                defaultTagColorSetting: defaultTagColorSetting, customTagMap: [:]
            )
            
        case .large:
            let june3 = SectionModel(
                title: "widget.events.sample::june3".localized(),
                events: [ runningEvent, lunchEvent, callTodoEvent ],
                shouldAccentTitle: true
            )
            
            let july = SectionModel(title: "widget.events.sample::july16".localized(), events: [
                runningEvent, surfingEvent
            ])
            let july21 = SectionModel(
                title: "widget.events.sample::july21".localized(), events: [
                    meeting
                ]
            )
            let july27 = SectionModel(
                title: "widget.events.sample::july29".localized(), events: [
                    golf, recycle
                ]
            )
            let aug2 = SectionModel(
                title: "widget.events.sample::aug2".localized(), events: [
                    takeMedicine, meeting
                ]
            )
            let aug3 = SectionModel(
                title: "widget.events.sample::aug3".localized(), events: [
                    watering
                ]
            )
            let oct = SectionModel(
                title: "widget.events.sample::oct10".localized(), events: [
                    holiday
                ]
            )
            return .init(
                pages: [
                    .init(sections: [june3, july, july21, july27]),
                    .init(sections: [aug2, aug3, oct], needBottomSpace: true)
                ],
                defaultTagColorSetting: defaultTagColorSetting, customTagMap: [:]
            )
        }
    }
}

extension EventListWidgetViewModel: EventColorMaterials { }
