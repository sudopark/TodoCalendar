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
import CalendarPresentation
import WidgetScenes


struct EventAndMonthWidgetViewModelProvider {
    
    private let eventListViewModelProvider: EventListWidgetViewModelProvider
    private let monthViewModelProvider: MonthWidgetViewModelProvider
    private let styleRepository: any WidgetStyleRepository
    
    init(
        eventListViewModelProvider: EventListWidgetViewModelProvider,
        monthViewModelProvider: MonthWidgetViewModelProvider,
        styleRepository: any WidgetStyleRepository
    ) {
        self.eventListViewModelProvider = eventListViewModelProvider
        self.monthViewModelProvider = monthViewModelProvider
        self.styleRepository = styleRepository
    }
    
    func getViewModel(
        _ time: Date, style: WidgetStyleId.Style = .default
    ) async throws -> EventAndMonthWidgetViewModel {
        
        let event = try await eventListViewModelProvider.getEventListViewModel(
            for: time, widgetSize: .small
        )
        let month = try await monthViewModelProvider.getMonthViewModel(time)
        let resolved = self.styleRepository.resolveStyle(of: .eventAndMonthMedium, style: style)
        let look = WidgetLook(globalSetting: event.look.globalSetting, appliedStyle: resolved)
        return EventAndMonthWidgetViewModel(event: event, month: month)
            .applying(look)
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
                    |> \.background .~ model.event.look.background
                )
            } catch {
                completion(.init(date: now, result: .failure(.init(error: error))))
            }
        }
    }
}
