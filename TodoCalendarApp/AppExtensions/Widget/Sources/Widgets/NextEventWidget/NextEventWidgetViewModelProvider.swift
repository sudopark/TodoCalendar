//
//  NextEventWidgetViewModelProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 1/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - NextEventWidgetViewModel

struct NextEventWidgetViewModel: Sendable {
    let timeText: EventTimeText?
    let eventTitle: String
    var locationText: String?
    var refreshAfter: Date?
    fileprivate var timeRawValue: EventTime?
    var eventLink: URL?
    
    init(
        timeText: EventTimeText?,
        eventTitle: String,
        refreshAfter: Date? = nil
    ) {
        self.timeText = timeText
        self.eventTitle = eventTitle
        self.refreshAfter = refreshAfter
    }
    
    static var empty: Self {
        return .init(
            timeText: nil, eventTitle: "widget.next.noEvent".localized(), refreshAfter: nil
        )
    }
    
    static var sample: Self {
        return .init(timeText: .init(text: "11:29"), eventTitle: "widget.next.sample".localized())
    }
}


// MARK: - NextEventListWidgetViewModel

struct NextEventListWidgetViewModel: Sendable {
    let models: [NextEventWidgetViewModel]
    var refreshAfter: Date?
    
    static var empty: Self {
        return .init(models: [])
    }
    
    static var sample: Self {
        return .init(models: [
            .init(timeText: .init(text: "10:00"), eventTitle: "widget.next.sample".localized()),
            .init(timeText: .init(text: "12:00"), eventTitle: "widget.weeks.sample::lunch".localized()),
            .init(timeText: .init(text: "16:30"), eventTitle: "widget.weeks.sample::call".localized())
        ])
    }
}


// MARK: - NextEventWidgetViewModelBuilder

struct NextEventWidgetViewModelBuilder {
    
    let timeZone: TimeZone
    let dayRange: Range<TimeInterval>
    let is24Form: Bool
    
    func build(_ event: TodayNextEvent?) throws -> NextEventWidgetViewModel {
        guard let event,
              var model = try self.convertToNextModel(event.nextEvent)
        else {
            return .empty
        }

        model.refreshAfter = self.selectRefreshTime(model.timeRawValue, event.andThenNextEventStartDate)
        
        return model
    }
    
    func build(_ events: TodayNextEvents) throws -> NextEventListWidgetViewModel {
        guard !events.nextEvents.isEmpty
        else {
            return .empty
        }
        
        let nextEvents = events.nextEvents.prefix(3).map { $0 }
        
        let models = nextEvents.compactMap { try? self.convertToNextModel($0) }
        let secondEventTime = models[safe: 1]?.timeRawValue.map {
            Date(timeIntervalSince1970: $0.lowerBoundWithFixed)
        }
        let refreshTime = self.selectRefreshTime(models.first?.timeRawValue, secondEventTime)
        return .init(models: models, refreshAfter: refreshTime)
    }
    
    private func convertToNextModel(_ event: any CalendarEvent) throws -> NextEventWidgetViewModel? {
        
        guard !(event is HolidayCalendarEvent) else { return nil }
        
        guard let time = event.eventTime else {
            throw RuntimeError("event time not exists")
        }
        
        let link: EventDeepLinkBuilder? = switch event {
        case let todo as TodoCalendarEvent:
                .todo(id: todo.eventId)
        case let schedule as ScheduleCalendarEvent:
            schedule.eventTime.flatMap {
                EventDeepLinkBuilder.schedule(id: schedule.eventIdWithoutTurn, time: $0)
            }
        case let holiday as HolidayCalendarEvent:
                .holiday(id: holiday.eventId)
        case let google as GoogleCalendarEvent:
                .google(id: google.eventId, calendarId: google.calendarId)
        default: nil
        }
        
        return .init(
            timeText: EventTimeText.fromLowerBound(time, timeZone, !is24Form),
            eventTitle: event.name
        )
        |> \.locationText .~ event.locationText
        |> \.timeRawValue .~ time
        |> \.eventLink .~ link?.build()
    }
    
    private func selectRefreshTime(_ current: EventTime?, _ next: Date?) -> Date? {
        guard let current, let next else { return nil }
        
        let (start, end) = (current.lowerBoundWithFixed, current.upperBoundWithFixed)
        if end < next.timeIntervalSince1970 {
            return Date(timeIntervalSince1970: end)
        } else {
            return Date(
                timeIntervalSince1970: max(start, next.timeIntervalSince1970-10*60)
            )
        }
    }
}


// MARK: - NextEventWidgetViewModelProvider

final class NextEventWidgetViewModelProvider {
    
    private let eventsFetchusecase: any CalendarEventFetchUsecase
    private let calednarSettingRepository: any CalendarSettingRepository
    private let localeProvider: any LocaleProvider
    
    init(
        eventsFetchusecase: any CalendarEventFetchUsecase,
        calednarSettingRepository: any CalendarSettingRepository,
        localeProvider: any LocaleProvider
    ) {
        self.eventsFetchusecase = eventsFetchusecase
        self.calednarSettingRepository = calednarSettingRepository
        self.localeProvider = localeProvider
    }
}

extension NextEventWidgetViewModelProvider {
    
    func getNextEventModel(for today: Date) async throws -> NextEventWidgetViewModel {
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calendar.dayRange(today).unwrap()
        
        let event = try await eventsFetchusecase.fetchNextEvent(
            today, within: todayRange, timeZone
        )
        let builder = NextEventWidgetViewModelBuilder(
            timeZone: timeZone, dayRange: todayRange,
            is24Form: self.localeProvider.is24HourFormat()
        )
        let model = try builder.build(event)
        return model
    }
    
    func getNextEventModels(for today: Date) async throws -> NextEventListWidgetViewModel {
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calendar.dayRange(today).unwrap()
        
        let events = try await eventsFetchusecase.fetchNextEvents(
            today, withIn: todayRange, timeZone
        )
        let builder = NextEventWidgetViewModelBuilder(
            timeZone: timeZone, dayRange: todayRange,
            is24Form: self.localeProvider.is24HourFormat()
        )
        let model = try builder.build(events)
        return model
    }
}

private extension EventTimeText {
    
    static func fromLowerBound(
        _ time: EventTime, _ timeZone: TimeZone, _ isShort: Bool) -> EventTimeText
    {
        switch time {
        case .at(let interval):
            return .init(time: interval, timeZone, isShort)
        case .period(let range):
            return .init(time: range.lowerBound, timeZone, isShort)
        case .allDay(let range, _):
            return .init(day: range.lowerBound, timeZone)
        }
    }
}
