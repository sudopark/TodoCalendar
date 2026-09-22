//
//  EventAndForemostWidgetTimelineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 4/13/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation
import WidgetScenes


struct EventAndForemostWidgetViewModelProvider {
    
    private let eventListViewModelProvider: EventListWidgetViewModelProvider
    private let foremostEventViewModelProvider: ForemostEventWidgetViewModelProvider
    private let styleRepository: any WidgetStyleRepository
    
    init(
        eventListViewModelProvider: EventListWidgetViewModelProvider,
        foremostEventViewModelProvider: ForemostEventWidgetViewModelProvider,
        styleRepository: any WidgetStyleRepository
    ) {
        self.eventListViewModelProvider = eventListViewModelProvider
        self.foremostEventViewModelProvider = foremostEventViewModelProvider
        self.styleRepository = styleRepository
    }
    
    func getViewModel(
        _ time: Date, style: WidgetStyleId.Style = .default
    ) async throws -> EventAndForemostWidgetViewModel {
        let eventList = try await self.eventListViewModelProvider.getEventListViewModel(
            for: time, widgetSize: .small
        )
        let foremost = try await self.foremostEventViewModelProvider.getViewModel(time)
        let resolved = self.styleRepository.resolveStyle(of: .eventAndForemostMedium, style: style)
        let look = WidgetLook(globalSetting: eventList.look.globalSetting, appliedStyle: resolved)
        return EventAndForemostWidgetViewModel(event: eventList, foremost: foremost)
            .applying(look)
    }
}


struct EventAndForemostWidgetViewTimelineProvider: AppIntentTimelineProvider {
    
    typealias Intent = EventAndForemostWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<EventAndForemostWidgetViewModel>
    
    func placeholder(in context: Context) -> Entry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let look = WidgetLook(
            globalSetting: builder.loadWidgetAppearanceSetting(),
            appliedStyle: builder.resolveWidgetStyle(of: .eventAndForemostMedium, style: .default)
        )
        let model = EventAndForemostWidgetViewModel(
            event: EventListWidgetViewModel.sample(size: .small),
            foremost: ForemostEventWidgetViewModel.sample()
        )
        .applying(look)
        return .init(date: Date(), result: .success(model))
            |> \.background .~ model.event.look.background
    }
    
    func snapshot(
        for configuration: EventAndForemostWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: EventAndForemostWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        let entry = await self.loadEntry(configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(_ style: WidgetStyleId.Style) async -> Entry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeEventListAndForemostWidgetViewModelProvider(
            targetEventTagId: .default
        )
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
