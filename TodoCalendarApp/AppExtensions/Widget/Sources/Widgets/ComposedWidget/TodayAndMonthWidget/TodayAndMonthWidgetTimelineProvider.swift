//
//  TodayAndMonthWidgetTimelineProvider.swift
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


struct TodayAndMonthWidgetViewModelProvider {
    
    private let todayViewModelProvider: TodayWidgetViewModelProvider
    private let monthViewModelProvider: MonthWidgetViewModelProvider
    private let styleRepository: any WidgetStyleRepository
    
    init(
        todayViewModelProvider: TodayWidgetViewModelProvider,
        monthViewModelProvider: MonthWidgetViewModelProvider,
        styleRepository: any WidgetStyleRepository
    ) {
        self.todayViewModelProvider = todayViewModelProvider
        self.monthViewModelProvider = monthViewModelProvider
        self.styleRepository = styleRepository
    }
    
    func getViewModel(
        _ time: Date, style: WidgetStyleId.Style = .default
    ) async throws -> TodayAndMonthWidgetViewModel {
        
        let today = try await todayViewModelProvider.getTodayViewModel(for: time)
        let month = try await monthViewModelProvider.getMonthViewModel(time)
        let resolved = self.styleRepository.resolveStyle(of: .todayAndMonthMedium, style: style)
        let look = WidgetLook(globalSetting: today.look.globalSetting, appliedStyle: resolved)
        return TodayAndMonthWidgetViewModel(today: today, month: month)
            .applying(look)
    }
}

struct TodayAndMonthWidgetTimelineProvider: AppIntentTimelineProvider {
    
    typealias Intent = TodayAndMonthWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<TodayAndMonthWidgetViewModel>
    
    func placeholder(in context: Context) -> Entry {
        return .init(date: Date()) {
            .init(today: TodayWidgetViewModel.sample(),
                  month: try MonthWidgetViewModel.makeSample()
            )
        }
    }
    
    func snapshot(
        for configuration: TodayAndMonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: TodayAndMonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        let entry = await self.loadEntry(configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(_ style: WidgetStyleId.Style) async -> Entry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeTodayAndMonthWidgetViewModelProvider()
        let now = Date()
        do {
            let model = try await viewModelProvider.getViewModel(now, style: style)
            return .init(date: now, result: .success(model))
                |> \.background .~ model.month.look.background
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
