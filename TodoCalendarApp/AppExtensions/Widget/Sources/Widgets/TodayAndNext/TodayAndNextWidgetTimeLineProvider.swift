//
//  TodayAndNextWidgetTimeLineProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 12/21/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


struct TodayAndNextWidgetTimeLineProvider: AppIntentTimelineProvider {
    
    typealias Intent = EventListComponentSelectIntent
    typealias Entry = ResultTimelineEntry<TodayAndNextWidgetViewModel>
}


extension TodayAndNextWidgetTimeLineProvider {
    
    func placeholder(in context: Context) -> ResultTimelineEntry<TodayAndNextWidgetViewModel> {
        let sample = TodayAndNextWidgetViewModel.sample()
        return .init(date: Date(), result: .success(sample))
    }
    
    func snapshot(
        for configuration: EventListComponentSelectIntent,
        in context: Context
    ) async -> ResultTimelineEntry<TodayAndNextWidgetViewModel> {
        
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        
        return await self.loadEntry(
            selected: configuration.eventTypes,
            excludeAllDayEvent: configuration.excludeAllDayEvent
        )
    }
    
    func timeline(
        for configuration: EventListComponentSelectIntent,
        in context: Context
    ) async -> Timeline<ResultTimelineEntry<TodayAndNextWidgetViewModel>> {
        let entry = await self.loadEntry(
            selected: configuration.eventTypes, excludeAllDayEvent: configuration.excludeAllDayEvent
        )
        switch entry.result {
        case .success(let model):
            let defNextTime = Date().nextUpdateTime
            let refreshDate = model.refreshAfter.map { Date(timeIntervalSince1970: $0) } ?? defNextTime
            let minRefreshTime = min(defNextTime, refreshDate)
            return Timeline(entries: [entry], policy: .after(minRefreshTime))
            
        case .failure:
            return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
        }
    }
    
    private func loadEntry(
        selected: [EventTypeEntity]?,
        excludeAllDayEvent: Bool
    ) async -> Entry {
        
        let tagIds = selected?.map { EventTagId($0) }
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeTodayAndNextWidgetViewModelProvider(
            targetEventTagIds: tagIds, excludeAllDayEvent: excludeAllDayEvent
        )
        let now = Date()
        do {
            let model = try await viewModelProvider.getViewModel(for: now)
            return .init(date: now, result: .success(model))
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
