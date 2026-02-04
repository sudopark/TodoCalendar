//
//  EventListWidgetTimeLineProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


struct EventListWidgetTimeLineProvider: AppIntentTimelineProvider {
    
    typealias Intent = EventTypeSelectIntent
    typealias Entry = ResultTimelineEntry<EventListWidgetViewModel>
    
    init() { }
}

extension EventListWidgetTimeLineProvider {
    
    func placeholder(
        in context: Context
    ) -> ResultTimelineEntry<EventListWidgetViewModel> {
        let sample = EventListWidgetViewModel.sample(
            size: .init(context.family)
        )
        return .init(date: Date(), result: .success(sample))
    }
    
    func snapshot(
        for configuration: EventTypeSelectIntent,
        in context: Context
    ) async -> ResultTimelineEntry<EventListWidgetViewModel> {
        
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        
        return await self.loadEntry(configuration.eventTypes, context)
    }
    
    func timeline(
        for configuration: EventTypeSelectIntent, in context: Context
    ) async -> Timeline<ResultTimelineEntry<EventListWidgetViewModel>> {
        
        let entry = await self.loadEntry(configuration.eventTypes, context)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(
        _ selected: [EventTypeEntity]?,
        _ context: Context
    ) async -> Entry {
        
        let tagIds = selected?.map { EventTagId($0) }
        let size = EventListWidgetSize(context.family)
        
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeEventListViewModelProvider(targetEventTagIds: tagIds)
        let now = Date()
        do {
            let model = try await viewModelProvider.getEventListViewModel(
                for: now,
                widgetSize: size
            )
            return .init(date: now, result: .success(model))
                |> \.background .~ model.widgetSetting.background
            
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}

extension EventTagId {
    
    init(_ entity: EventTypeEntity) {
        if entity.isDefaultTag {
            self = .default
        } else if let serviceId = entity.externalServiceId {
            self = .externalCalendar(serviceId: serviceId, id: entity.id)
        } else {
            self = .custom(entity.id)
        }
    }
}
