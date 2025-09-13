//
//  ForemostEventWidgetViewModel+Provider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/17/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - ForemostEventWidgetViewModel

struct ForemostEventWidgetViewModel {
    
    var eventModel: (any EventCellViewModel)?
    let defaultTagColorSetting: DefaultEventTagColorSetting
    var tag: CustomEventTag?
    
    static func sample() -> ForemostEventWidgetViewModel {
        
        let event = TodoEventCellViewModel("tood", name: "widget.events.foremost::sample::message".localized())
            |> \.periodText .~ .doubleText(
                .init(text: "calendar::event_time::todo".localized()), .init(text: "13:00")
            )
        let defaultTagColorSetting = DefaultEventTagColorSetting(
            holiday: "#D6236A", default: "#088CDA"
        )
        return .init(eventModel: event, defaultTagColorSetting: defaultTagColorSetting)
    }
}


// MARK: ForemostEventWidgetViewModelProvider

final class ForemostEventWidgetViewModelProvider {
    
    private let eventFetchUsecase: any CalendarEventFetchUsecase
    private let calendarSettingRepository: any CalendarSettingRepository
    private let appSettingRepository: any AppSettingRepository
    private let localeProvider: any LocaleProvider
    
    init(
        eventFetchUsecase: any CalendarEventFetchUsecase,
        calendarSettingRepository: any CalendarSettingRepository,
        appSettingRepository: any AppSettingRepository,
        localeProvider: any LocaleProvider
    ) {
        self.eventFetchUsecase = eventFetchUsecase
        self.calendarSettingRepository = calendarSettingRepository
        self.appSettingRepository = appSettingRepository
        self.localeProvider = localeProvider
    }
}

extension ForemostEventWidgetViewModelProvider {
    
    func getViewModel(_ refTime: Date) async throws -> ForemostEventWidgetViewModel {
        
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        let eventModel = try await self.loadForemostEventModel(refTime, setting.calendar)
        return ForemostEventWidgetViewModel(
            eventModel: eventModel.0,
            defaultTagColorSetting: setting.defaultTagColor,
            tag: eventModel.1
        )
    }
    
    private func loadForemostEventModel(
        _ refTime: Date,
        _ setting: CalendarAppearanceSettings
    ) async throws -> ((any EventCellViewModel)?, CustomEventTag?) {
        let timeZone = self.calendarSettingRepository.loadUserSelectedTImeZone() ?? .current
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let dayRange = try calendar.dayRange(refTime).unwrap()
        let eventAndTag = try await self.eventFetchUsecase.fetchForemostEvent()
        let is24hourForm = self.localeProvider.is24HourFormat()
        var model: (any EventCellViewModel)? = {
            switch eventAndTag.foremostEvent {
            case let todo as TodoEvent:
                let event = TodoCalendarEvent(todo, in: timeZone, isForemost: true)
                return TodoEventCellViewModel(
                    event, in: dayRange, timeZone, is24hourForm
                )
            case let schedule as ScheduleEvent:
                let isPast = schedule.time.lowerBoundWithFixed < dayRange.lowerBound
                guard !isPast else { return nil }
                let event = ScheduleCalendarEvent.events(from: schedule, in: timeZone)[0]
                return ScheduleEventCellViewModel(
                    event, in: dayRange, timeZone: timeZone, is24hourForm
                )
            default: return nil
            }
        }()
        return (model, eventAndTag.tag)
    }
}
