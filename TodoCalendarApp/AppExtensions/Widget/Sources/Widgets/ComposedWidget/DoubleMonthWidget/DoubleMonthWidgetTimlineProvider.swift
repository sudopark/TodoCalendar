//
//  DoubleMonthWidgetTimlineProvider.swift
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

struct DoubleMonthWidgetViewModelProvider {
    
    private let settingRepository: any CalendarSettingRepository
    private let monthViewModelProvider: MonthWidgetViewModelProvider
    private let styleRepository: any WidgetStyleRepository
    
    init(
        settingRepository: any CalendarSettingRepository,
        monthViewModelProvider: MonthWidgetViewModelProvider,
        styleRepository: any WidgetStyleRepository
    ) {
        self.settingRepository = settingRepository
        self.monthViewModelProvider = monthViewModelProvider
        self.styleRepository = styleRepository
    }
    
    func getviewModel(
        _ now: Date, style: WidgetStyleId.Style = .default
    ) async throws -> DoubleMonthWidgetViewModel {
        
        let currentMonthModel = try await self.monthViewModelProvider.getMonthViewModel(now)
        
        let timeZone = self.settingRepository.loadUserSelectedTImeZone() ?? .current
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let nextMonth = try calendar.addMonth(1, from: now).unwrap()
        
        let nextMonthModel = try await self.monthViewModelProvider.getMonthViewModel(nextMonth)
        |> \.todayIdentifier .~ nil
        
        let resolved = self.styleRepository.resolveStyle(of: .doubleMonthMedium, style: style)
        let look = WidgetLook(globalSetting: currentMonthModel.look.globalSetting, appliedStyle: resolved)
        return DoubleMonthWidgetViewModel(current: currentMonthModel, next: nextMonthModel)
            .applying(look)
    }
}

struct DoubleMonthWidgetTimlineProvider: AppIntentTimelineProvider {
    
    typealias Intent = DoubleMonthWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<DoubleMonthWidgetViewModel>
    
    func placeholder(in context: Context) -> Entry {
        return .init(date: Date()) {
            .init(
                current: try MonthWidgetViewModel.makeSample(),
                next: try MonthWidgetViewModel.makeSampleNextMonth()
            )
        }
    }
    
    func snapshot(
        for configuration: DoubleMonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Entry {
        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.resolvedStyle)
    }
    
    func timeline(
        for configuration: DoubleMonthWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<Entry> {
        let entry = await self.loadEntry(configuration.resolvedStyle)
        return Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
    }
    
    private func loadEntry(_ style: WidgetStyleId.Style) async -> Entry {
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeDoubleMonthViewModelProvider()
        let now = Date()
        do {
            let model = try await viewModelProvider.getviewModel(now, style: style)
            return .init(date: now, result: .success(model))
                |> \.background .~ model.current.look.background
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
