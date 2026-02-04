//
//  EventAndMonthWidgetTimelineProvider.swift
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
import CalendarScenes


struct EventAndMonthWidgetViewModel {
    let event: EventListWidgetViewModel
    let month: MonthWidgetViewModel
}


struct EventAndMonthWidgetViewModelProvider {
    
    private let eventListViewModelProvider: EventListWidgetViewModelProvider
    private let monthViewModelProvider: MonthWidgetViewModelProvider
    
    init(
        eventListViewModelProvider: EventListWidgetViewModelProvider,
        monthViewModelProvider: MonthWidgetViewModelProvider
    ) {
        self.eventListViewModelProvider = eventListViewModelProvider
        self.monthViewModelProvider = monthViewModelProvider
    }
    
    func getViewModel(_ time: Date) async throws -> EventAndMonthWidgetViewModel {
        
        return EventAndMonthWidgetViewModel(
            event: try await eventListViewModelProvider.getEventListViewModel(
                for: time, widgetSize: .small
            ),
            month: try await monthViewModelProvider.getMonthViewModel(time)
        )
    }
}

struct EventAndMonthWidgetTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<EventAndMonthWidgetViewModel>
    
    func placeholder(in context: Context) -> Entry {
        return .init(date: Date()) {
            .init(
                event: EventListWidgetViewModel.sample(
                    size: .small
                ),
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
        getEntry(context) { entry in
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @Sendable @escaping (Timeline<Entry>) -> Void) {
        self.getEntry(context) { entry in
            let timeline = Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
            completion(timeline)
        }
    }
    
    private func getEntry(_ context: Context, _ completion: @Sendable @escaping (Entry) -> Void) {
        
        Task {
            let builer = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builer.makeEventAndMonthWidgetViewModelProvider(targetEventTagId: .default)
            let now = Date()
            do {
                let model = try await viewModelProvider.getViewModel(now)
                completion(
                    .init(date: now, result: .success(model))
                    |> \.background .~ model.event.widgetSetting.background
                )
            } catch {
                completion(.init(date: now, result: .failure(.init(error: error))))
            }
        }
    }
}
