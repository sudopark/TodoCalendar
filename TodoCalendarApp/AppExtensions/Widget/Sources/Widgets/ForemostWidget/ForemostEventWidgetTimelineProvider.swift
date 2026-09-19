//
//  ForemostEventWidgetTimelineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/19/24.
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


struct ForemostEventWidgetTimelineProvider: AppIntentTimelineProvider {
    
    typealias Intent = ForemostWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<ForemostEventWidgetViewModel>
    init() { }
}

extension ForemostEventWidgetTimelineProvider {
    
    func placeholder(in context: Context) -> Entry {
        let sample = ForemostEventWidgetViewModel.sample()
        return .init(date: Date(), result: .success(sample))
    }
    
    func snapshot(
        for configuration: ForemostWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(context.family, configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: ForemostWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        
        let entry = await self.loadEntry(context.family, configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(
        _ family: WidgetFamily, _ style: WidgetStyleId.Style
    ) async -> Entry {
        
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeForemostEventWidgetViewModelProvider()
        let now = Date()
        do {
            let model = try await viewModelProvider.getViewModel(
                now,
                variant: family == .accessoryInline ? .foremostInline : .foremostSmall,
                style: style
            )
            return .init(date: now, result: .success(model))
                |> \.background .~ model.look.background
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
