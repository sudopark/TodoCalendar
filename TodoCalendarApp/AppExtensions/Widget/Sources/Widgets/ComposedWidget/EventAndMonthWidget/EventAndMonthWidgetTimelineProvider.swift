//
//  EventAndMonthWidgetTimelineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/4/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation
import WidgetScenes


struct EventAndMonthWidgetViewModelProvider {
    
    private let eventListViewModelProvider: EventListWidgetViewModelProvider
    private let monthViewModelProvider: MonthWidgetViewModelProvider
    private let styleRepository: any WidgetStyleRepository
    
    init(
        eventListViewModelProvider: EventListWidgetViewModelProvider,
        monthViewModelProvider: MonthWidgetViewModelProvider,
        styleRepository: any WidgetStyleRepository
    ) {
        self.eventListViewModelProvider = eventListViewModelProvider
        self.monthViewModelProvider = monthViewModelProvider
        self.styleRepository = styleRepository
    }
    
    func getViewModel(
        _ time: Date, style: WidgetStyleId.Style = .default
    ) async throws -> EventAndMonthWidgetViewModel {
        
        let event = try await eventListViewModelProvider.getEventListViewModel(
            for: time, widgetSize: .small
        )
        let month = try await monthViewModelProvider.getMonthViewModel(time)
        let resolved = self.styleRepository.resolveStyle(of: .eventAndMonthMedium, style: style)
        let look = WidgetLook(globalSetting: event.look.globalSetting, appliedStyle: resolved)
        return EventAndMonthWidgetViewModel(event: event, month: month)
            .applying(look)
    }
}

struct EventAndMonthWidgetTimelineProvider: AppIntentTimelineProvider {
    
    typealias Intent = EventAndMonthWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<EventAndMonthWidgetViewModel>
    
    func placeholder(in context: Context) -> Entry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let look = WidgetLook(
            globalSetting: builder.loadWidgetAppearanceSetting(),
            appliedStyle: builder.resolveWidgetStyle(of: .eventAndMonthMedium, style: .default)
        )
        let entry = Entry(date: Date()) {
            EventAndMonthWidgetViewModel(
                event: EventListWidgetViewModel.sample(size: .small),
                month: try MonthWidgetViewModel.makeSample()
            )
            .applying(look)
        }
        guard case .success(let model) = entry.result else { return entry }
        return entry |> \.background .~ model.event.look.background
    }
    
    func snapshot(
        for configuration: EventAndMonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: EventAndMonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        let entry = await self.loadEntry(configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(_ style: WidgetStyleId.Style) async -> Entry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeEventAndMonthWidgetViewModelProvider(targetEventTagId: .default)
        let now = Date()
        do {
            let model = try await viewModelProvider.getViewModel(now, style: style)
            return .init(date: now, result: .success(model))
                |> \.background .~ model.event.look.background
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
