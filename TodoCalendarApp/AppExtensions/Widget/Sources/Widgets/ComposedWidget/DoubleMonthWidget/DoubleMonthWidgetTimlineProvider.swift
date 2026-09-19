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

struct DoubleMonthWidgetTimlineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<DoubleMonthWidgetViewModel>
    
    func placeholder(in context: Context) -> Entry {
        return .init(date: Date()) {
            .init(
                current: try MonthWidgetViewModel.makeSample(),
                next: try MonthWidgetViewModel.makeSampleNextMonth()
            )
        }
    }
    
    func getSnapshot(in context: Context, completion: @Sendable @escaping (Entry) -> Void) {
        guard context.isPreview == false
        else {
            completion(placeholder(in: context))
            return
        }
        self.getEntry { entry in
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @Sendable @escaping (Timeline<Entry>) -> Void) {
        
        self.getEntry { entry in
            let timeline = Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
            completion(timeline)
        }
    }
    
    private func getEntry(_ completion: @Sendable @escaping (Entry) -> Void) {
     
        Task {
            let builer = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builer.makeDoubleMonthViewModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getviewModel(now)
                completion(
                    .init(date: now, result: .success(model))
                    |> \.background .~ model.current.look.background
                )
            } catch {
                completion(.init(date: now, result: .failure(.init(error: error))))
            }
        }
    }
}
