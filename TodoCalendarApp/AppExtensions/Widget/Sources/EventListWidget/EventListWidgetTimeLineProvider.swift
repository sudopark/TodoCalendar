//
//  EventListWidgetTimeLineProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 6/2/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


struct EventListWidgetTimeLineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<EventListWidgetViewModel>
    
    init() { }
}

extension EventListWidgetTimeLineProvider {
    
    func placeholder(
        in context: Context
    ) -> ResultTimelineEntry<EventListWidgetViewModel> {
        let sample = EventListWidgetViewModel.sample()
        return .init(date: Date(), result: .success(sample))
    }
    
    func getSnapshot(
        in context: Context,
        completion: @escaping (ResultTimelineEntry<EventListWidgetViewModel>
        ) -> Void) {
        
        guard context.isPreview == false
        else {
            completion(
                .init(date: Date()) { EventListWidgetViewModel.sample() }
            )
            return
        }
        
        getEntry { entry in
            completion(entry)
        }
    }
    
    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ResultTimelineEntry<EventListWidgetViewModel>>) -> Void
    ) {
        
        self.getEntry { entry in
            let timeline = Timeline(
                entries: [entry],
                policy: .after(Date().nextUpdateTime)
            )
            completion(timeline)
        }
    }
    
    private func getEntry(_ completion: @escaping (Entry) -> Void) {
        
        Task {
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeEventListViewModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getEventListViewModel(for: now)
                completion(
                    .init(date: now, result: .success(model))
                )
            } catch {
                completion(
                    .init(date: now, result: .failure(.init(error: error)))
                )
            }
        }
    }
}
