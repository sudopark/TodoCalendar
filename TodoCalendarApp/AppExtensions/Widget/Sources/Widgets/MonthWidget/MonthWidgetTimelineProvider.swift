//
//  MonthWidgetTimelineProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/19/24.
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


struct MonthWidgetTimelineProvider: AppIntentTimelineProvider {
    
    typealias Intent = MonthWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<MonthWidgetViewModel>
    
    init() { }
}

extension MonthWidgetTimelineProvider {
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) {
            try MonthWidgetViewModel.makeSample()
        }
    }
    
    func snapshot(
        for configuration: MonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: MonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        
        let entry = await self.loadEntry(configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(_ style: WidgetStyleId.Style) async -> Entry {
        
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeMonthViewModelProvider()
        let now = Date()
        do {
            let model = try await viewModelProvider.getMonthViewModel(now, style: style)
            return .init(date: now, result: .success(model))
                |> \.background .~ model.widgetSetting.background
            
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
