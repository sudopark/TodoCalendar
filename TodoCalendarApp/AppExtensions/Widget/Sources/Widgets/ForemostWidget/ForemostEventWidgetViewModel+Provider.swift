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
import CalendarPresentation
import WidgetScenes


// MARK: ForemostEventWidgetViewModelProvider

final class ForemostEventWidgetViewModelProvider {
    
    private let eventFetchUsecase: any CalendarEventFetchUsecase
    private let calendarSettingRepository: any CalendarSettingRepository
    private let appSettingRepository: any AppSettingRepository
    private let localeProvider: any LocaleProvider
    private let styleRepository: any WidgetStyleRepository
    
    init(
        eventFetchUsecase: any CalendarEventFetchUsecase,
        calendarSettingRepository: any CalendarSettingRepository,
        appSettingRepository: any AppSettingRepository,
        localeProvider: any LocaleProvider,
        styleRepository: any WidgetStyleRepository
    ) {
        self.eventFetchUsecase = eventFetchUsecase
        self.calendarSettingRepository = calendarSettingRepository
        self.appSettingRepository = appSettingRepository
        self.localeProvider = localeProvider
        self.styleRepository = styleRepository
    }
}

extension ForemostEventWidgetViewModelProvider {
    
    /// 잠금화면 변형은 꾸미기 대상이 아니라 스타일 좌표를 읽지 않는다 — 전역 설정만 따른다.
    func getViewModel(
        _ refTime: Date,
        variant: WidgetVariant = .foremostSmall,
        style: WidgetStyleId.Style = .default
    ) async throws -> ForemostEventWidgetViewModel {
        
        let setting = self.appSettingRepository.loadSavedViewAppearance()
        let resolved = variant.isCustomizable
            ? self.styleRepository.resolveStyle(of: variant, style: style)
            : nil
        let eventModel = try await self.loadForemostEventModel(refTime, setting.calendar)
        return ForemostEventWidgetViewModel(
            eventModel: eventModel.0,
            defaultTagColorSetting: setting.defaultTagColor,
            tag: eventModel.1
        )
        |> \.look .~ .init(globalSetting: setting.widget, appliedStyle: resolved)
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
