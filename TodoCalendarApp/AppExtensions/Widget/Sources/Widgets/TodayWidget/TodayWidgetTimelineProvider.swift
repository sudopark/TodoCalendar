//
//  TodayWidgetTimelineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/12/24.
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


struct TodayWidgetTimelineProvider: AppIntentTimelineProvider {
    
    typealias Intent = TodayWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<TodayWidgetViewModel>
    
    init() { }
}

extension TodayWidgetTimelineProvider {
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) { TodayWidgetViewModel.sample() }
    }
    
    func snapshot(
        for configuration: TodayWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: TodayWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        
        let entry = await self.loadEntry(configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(_ style: WidgetStyleId.Style) async -> Entry {
        
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeTodayViewModelProvider()
        let now = Date()
        do {
            let model = try await viewModelProvider.getTodayViewModel(for: now, style: style)
            return .init(date: now, result: .success(model))
                |> \.background .~ model.look.background
            
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
