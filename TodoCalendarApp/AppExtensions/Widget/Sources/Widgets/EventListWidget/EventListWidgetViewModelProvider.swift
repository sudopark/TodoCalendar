//
//  EventListWidgetViewModelProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/31/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - EventListWidgetViewModel

struct EventListWidgetViewModel {
    
    struct SectionModel {
        let sectionTitle: String
        var events: [any EventCellViewModel]
        var shouldAccentTitle: Bool = false
        var isCurrentTodos = false
        
        init(
            title: String,
            events: [any EventCellViewModel],
            shouldAccentTitle: Bool = false,
            isCurrentTodos: Bool = false
        ) {
            self.sectionTitle = title
            self.events = events
            self.shouldAccentTitle = shouldAccentTitle
            self.isCurrentTodos = isCurrentTodos
        }
        
        fileprivate struct Builder {
            let calendar: Calendar
            let timeZone: TimeZone
            let is24Form: Bool
            let customTags: [String: EventTag]
            
            func makeCurrentTodoListModel(
                _ events: [TodoCalendarEvent],
                _ range: Range<TimeInterval>
            ) -> SectionModel? {
                let models: [any EventCellViewModel] = events
                    .sortedByCreateTime()
                    .compactMap {
                        TodoEventCellViewModel($0, in: range, self.timeZone, self.is24Form)
                    }
                    .applyTag(customTags)
                guard !models.isEmpty else { return nil }
                return .init(
                    title: "Current todo".localized(),
                    events: models,
                    shouldAccentTitle: true,
                    isCurrentTodos: true
                )
            }
            
            func make(
                events: [any CalendarEvent],
                in range: Range<TimeInterval>,
                size: Int
            ) -> [SectionModel] {
                
                let start = Date(timeIntervalSince1970: range.lowerBound)
                
                let gatherEventsPerDay: (Int) -> EventListWidgetViewModel.SectionModel? = { offset in
                    guard let dayRange = calendar.addDays(offset, from: start).flatMap(calendar.dayRange(_:))
                    else { return nil }
                    
                    let eventsThisDay = events
                        .filter { $0.eventTime?.isOverlap(with: dayRange, in: self.timeZone) ?? false }
                        .sortedByEventTime()
                    let models = eventsThisDay.compactMap { event -> (any EventCellViewModel)? in
                        switch event {
                        case let todo as TodoCalendarEvent:
                            return TodoEventCellViewModel(todo, in: dayRange, timeZone, is24Form)
                        case let schedule as ScheduleCalendarEvent:
                            return ScheduleEventCellViewModel(schedule, in: dayRange, timeZone: timeZone, is24Form)
                        case let holiday as HolidayCalendarEvent:
                            return HolidayEventCellViewModel(holiday)
                        default: return nil
                        }
                    }.applyTag(self.customTags)
                    
                    guard offset == 0 || !models.isEmpty else { return nil }

                    let dateText = Date(timeIntervalSince1970: dayRange.lowerBound)
                        .text("EEE, MMM d".localized(), timeZone: timeZone)
                    return .init(
                        title: dateText,
                        events: models,
                        shouldAccentTitle: offset == 0
                    )
                }
                
                let models = (0..<size+1).compactMap(gatherEventsPerDay)
                if models.isEmpty {
                    let dateText = Date(timeIntervalSince1970: start.timeIntervalSince1970)
                        .text("EEE, MMM d".localized(), timeZone: timeZone)
                    let startDateModel = SectionModel(
                        title: dateText, events: [],
                        shouldAccentTitle: true
                    )
                    return [startDateModel]
                }
                return models
            }
        }
    }
    
    var lists: [SectionModel]
    let defaultTagColorSetting: DefaultEventTagColorSetting
    var needBottomSpace: Bool = false
    
    static func sample(maxItemCount: Int) -> EventListWidgetViewModel {
        
        let lunchEvent = ScheduleEventCellViewModel("lunch", name: "🍔 \("Lunch".localized())")
            |> \.tagColor .~ .default
            |> \.periodText .~ .singleText(.init(text: "1:00"))
        
        let callTodoEvent = TodoEventCellViewModel("call", name: "📞 \("Call Sara".localized())")
            |> \.tagColor .~ .default
            |> \.periodText .~ .singleText(.init(text: "3:00"))
        
        let surfingEvent = ScheduleEventCellViewModel("surfing", name: "🏄‍♂️ \("Surfing".localized())")
            |> \.tagColor .~ .default
            |> \.periodText .~ .singleText(.init(text: "Allday".localized()))
        
        let june3 = SectionModel(
            title: "TUE, JUN 3",
            events: [ lunchEvent, callTodoEvent ],
            shouldAccentTitle: true
        )
        
        let july = SectionModel(title: "SUN, JUL 16", events: [
            surfingEvent
        ])

        let defaultTagColorSetting = DefaultEventTagColorSetting(
            holiday: "#D6236A", default: "#088CDA"
        )
        
        return .init(
            lists: [june3, july],
            defaultTagColorSetting: defaultTagColorSetting
        )
        .prefixedEvents(maxItemCount)
    }
}


// MARK: - EventListWidgetViewModelProvider

final class EventListWidgetViewModelProvider {
    
    private let eventsFetchUsecase: any CalendarEventFetchUsecase
    private let appSettingRepository: any AppSettingRepository
    private let calendarSettingRepository: any CalendarSettingRepository
    
    init(
        eventsFetchUsecase: any CalendarEventFetchUsecase,
        appSettingRepository: any AppSettingRepository,
        calendarSettingRepository: any CalendarSettingRepository
    ) {
        self.eventsFetchUsecase = eventsFetchUsecase
        self.appSettingRepository = appSettingRepository
        self.calendarSettingRepository = calendarSettingRepository
    }
}

extension EventListWidgetViewModelProvider {
    
    func getEventListViewModel(
        for refDate: Date,
        maxItemCount: Int
    ) async throws -> EventListWidgetViewModel {
        
        let timeZone = self.calendarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        
        let dayEventLists = try await self.loadDayEventListModel(
            refDate, timeZone, setting.calendar.is24hourForm
        )
        
        return .init(
            lists: dayEventLists,
            defaultTagColorSetting: setting.defaultTagColor
        )
        .prefixedEvents(maxItemCount)
    }
    
    private func loadDayEventListModel(
        _ start: Date,
        _ timeZone: TimeZone,
        _ is24Form: Bool
    ) async throws -> [EventListWidgetViewModel.SectionModel] {
        
        let rangeSize: Int = 90
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        
        guard let endDate = calendar.addDays(rangeSize, from: start).flatMap(calendar.endOfDay(for:))
        else { return [] }
        
        let range = calendar.startOfDay(for: start).timeIntervalSince1970..<endDate.timeIntervalSince1970
        
        let totalEvents = try await self.eventsFetchUsecase.fetchEvents(in: range, timeZone)
        
        let builder = EventListWidgetViewModel.SectionModel.Builder(
            calendar: calendar, timeZone: timeZone, is24Form: is24Form, customTags: totalEvents.customTagMap
        )
        
        var modelLists = builder.make(events: totalEvents.eventWithTimes, in: range, size: rangeSize)
        
        if let currentModel = builder.makeCurrentTodoListModel(totalEvents.currentTodos, range) {
            modelLists.insert(currentModel, at: 0)
        }
        return modelLists
    }
}

private extension Array where Element == any CalendarEvent {
    
}

private extension Array where Element == EventCellViewModel {
    
    func applyTag(_ customs: [String: EventTag]) -> Array {
        return self.map { model in
            var model = model
            model.applyTagColor(
                model.tagId.customTagId.flatMap { customs[$0] }
            )
            return model
        }
    }
}


private extension EventListWidgetViewModel {
    
    func prefixedEvents(_ maxCount: Int) -> EventListWidgetViewModel {
        
        let totalEventCount = self.lists.flatMap { $0.events }.count
        let firstDateIndex = self.lists.firstIndex(where: { $0.isCurrentTodos == false })
        var remain = maxCount; var index = 0
        var days: [SectionModel] = []
        
        repeat {
            let day = self.lists[index].prefixIfNeed(remain)
            let isFirstDate = index == firstDateIndex
            if isFirstDate || !day.events.isEmpty {
                days.append(day)
                remain -= max(1, day.events.count)
            }
            index += 1
        } while index < self.lists.count && remain > 0
        
        return self
            |> \.lists .~ days
            |> \.needBottomSpace .~ (totalEventCount < maxCount)
    }
}

private extension EventListWidgetViewModel.SectionModel {
    
    func prefixIfNeed(_ remainCount: Int) -> EventListWidgetViewModel.SectionModel {
        if self.events.count > remainCount {
            return self |> \.events %~ { Array($0.prefix(remainCount)) }
        } else {
            return self
        }
    }
}

