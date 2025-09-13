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
    var refreshAfter: Date?
    fileprivate var timeRawValue: EventTime?
    
    init(
        timeText: EventTimeText?, eventTitle: String, refreshAfter: Date? = nil
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
        guard let event else {
            return .empty
        }
        
        var model = try self.convertToNextModel(event.nextEvent)
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
    
    private func convertToNextModel(_ event: any CalendarEvent) throws -> NextEventWidgetViewModel {
        
        switch event {
        case let todo as TodoCalendarEvent:
            guard let time = todo.eventTime else { throw RuntimeError("event time not exists") }
            return .init(
                timeText: EventTimeText.fromLowerBound(time, timeZone, !is24Form),
                eventTitle: todo.name
            )
            |> \.timeRawValue .~ time
            
        case let schedule as ScheduleCalendarEvent:
            guard let time = schedule.eventTime else { throw RuntimeError("event time not exists") }
            return .init(
                timeText: EventTimeText.fromLowerBound(time, timeZone, !is24Form),
                eventTitle: schedule.name
            )
            |> \.timeRawValue .~ time
            
        default:
            throw RuntimeError("not support event type")
        }
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
    private let appSettingRepository: any AppSettingRepository
    private let calednarSettingRepository: any CalendarSettingRepository
    
    init(
        eventsFetchusecase: any CalendarEventFetchUsecase,
        appSettingRepository: any AppSettingRepository,
        calednarSettingRepository: any CalendarSettingRepository
    ) {
        self.eventsFetchusecase = eventsFetchusecase
        self.appSettingRepository = appSettingRepository
        self.calednarSettingRepository = calednarSettingRepository
    }
}

extension NextEventWidgetViewModelProvider {
    
    func getNextEventModel(for today: Date) async throws -> NextEventWidgetViewModel {
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calendar.dayRange(today).unwrap()
        
        let event = try await eventsFetchusecase.fetchNextEvent(
            today, within: todayRange, timeZone
        )
        let builder = NextEventWidgetViewModelBuilder(
            timeZone: timeZone, dayRange: todayRange,
            is24Form: setting.calendar.is24hourForm
        )
        let model = try builder.build(event)
        return model
    }
    
    func getNextEventModels(for today: Date) async throws -> NextEventListWidgetViewModel {
        let timeZone = self.calednarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let todayRange = try calendar.dayRange(today).unwrap()
        
        let events = try await eventsFetchusecase.fetchNextEvents(
            today, withIn: todayRange, timeZone
        )
        let builder = NextEventWidgetViewModelBuilder(
            timeZone: timeZone, dayRange: todayRange,
            is24Form: setting.calendar.is24hourForm
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
