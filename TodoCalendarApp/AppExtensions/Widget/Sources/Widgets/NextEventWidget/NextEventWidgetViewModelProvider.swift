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


// MARK: - NextEventWidgetViewModel + builder

struct NextEventWidgetViewModel: Sendable {
    let timeText: String?
    let eventTitle: String
    var refreshAfter: Date?
    
    init(timeText: String?, eventTitle: String, refreshAfter: Date? = nil) {
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
        return .init(timeText: "11:29", eventTitle: "widget.next.sample".localized())
    }
}

struct NextEventWidgetViewModelBuilder {
    
    let timeZone: TimeZone
    let dayRange: Range<TimeInterval>
    let is24Form: Bool
    
    func build(_ event: TodayNextEvent?) throws -> NextEventWidgetViewModel {
        guard let event else {
            return .empty
        }
        
        func selectRefreshTime(_ eventTime: EventTime) -> Date? {
            guard let nextTime = event.andThenNextEventStartDate else { return nil }
            let (start, end) = (eventTime.lowerBoundWithFixed, eventTime.upperBoundWithFixed)
            if end < nextTime.timeIntervalSince1970 {
                return Date(timeIntervalSince1970: end)
            } else {
                return Date(
                    timeIntervalSince1970: max(start, nextTime.timeIntervalSince1970-10*60)
                )
            }
        }
        
        switch event.nextEvent {
        case let todo as TodoCalendarEvent:
            guard let time = todo.eventTime else { throw RuntimeError("event time not exists") }
            return .init(
                timeText: EventTimeText.fromLowerBound(time, timeZone, !is24Form).text,
                eventTitle: todo.name,
                refreshAfter: selectRefreshTime(time)
            )
            
        case let schedule as ScheduleCalendarEvent:
            guard let time = schedule.eventTime else { throw RuntimeError("event time not exists") }
            return .init(
                timeText: EventTimeText.fromLowerBound(time, timeZone, !is24Form).text,
                eventTitle: schedule.name,
                refreshAfter: selectRefreshTime(time)
            )
        default:
            throw RuntimeError("not support event type")
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
