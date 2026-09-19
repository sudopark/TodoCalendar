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

struct TodayAndMonthWidgetTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<TodayAndMonthWidgetViewModel>
    
    func placeholder(in context: Context) -> Entry {
        return .init(date: Date()) {
            .init(today: TodayWidgetViewModel.sample(),
                  month: try MonthWidgetViewModel.makeSample()
            )
        }
    }
    
    func getSnapshot(in context: Context, completion: @Sendable @escaping (Entry) -> Void) {
        guard context.isPreview == false
        else {
            completion(placeholder(in: context))
            return
        }
        getEntry { entry in
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
            let viewModelProvider = await builer.makeTodayAndMonthWidgetViewModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getViewModel(now)
                completion(
                    .init(date: now, result: .success(model))
                    |> \.background .~ model.month.look.background
                )
            } catch {
                completion(.init(date: now, result: .failure(.init(error: error))))
            }
        }
    }
}

