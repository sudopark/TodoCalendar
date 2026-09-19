//
//  WeekEventsWidgetTimelineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/3/24.
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


struct WeekEventsWidgetTimelineProvider: AppIntentTimelineProvider {
    
    typealias Intent = WeekEventsWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<WeekEventsViewModel>
    
    private let range: WeekEventsRange
    init(_ range: WeekEventsRange) {
        self.range = range
    }
}

extension WeekEventsWidgetTimelineProvider {
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) {
            WeekEventsViewModel.sample(range)
        }
    }
    
    func snapshot(
        for configuration: WeekEventsWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: WeekEventsWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        
        let entry = await self.loadEntry(configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(_ style: WidgetStyleId.Style) async -> Entry {
        
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeWeekEventsWidgetViewModelProvider()
        let now = Date()
        do {
            let model = try await viewModelProvider.getWeekEventsModel(
                from: now, range: self.range, style: style
            )
            return .init(date: now, result: .success(model))
                |> \.background .~ model.look.background
            
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
