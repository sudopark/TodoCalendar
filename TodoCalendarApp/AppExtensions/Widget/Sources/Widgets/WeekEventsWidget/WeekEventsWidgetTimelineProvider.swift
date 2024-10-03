//
//  WeekEventsWidgetTimelineProvider.swift
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
import CalendarScenes


struct WeekEventsWidgetTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<WeekEventsViewModel>
    
    private let range: WeekEventsRange
    init(_ range: WeekEventsRange) {
        self.range = range
    }
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) {
            WeekEventsViewModel.sample(range)
        }
    }
    
    func getSnapshot(in context: Context, completion: @Sendable @escaping (Entry) -> Void) {
       
        guard context.isPreview == false
        else {
            completion(
                .init(date: Date()) { WeekEventsViewModel.sample(range) }
            )
            return
        }
        
        self.getEntry { entry in
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @Sendable @escaping (Timeline<Entry>) -> Void
    ) {
        self.getEntry { entry in
            let timeline = Timeline(
                entries: [entry],
                policy: .after(Date().nextUpdateTime)
            )
            completion(timeline)
        }
    }
    
    private func getEntry(_ completion: @Sendable @escaping (Entry) -> Void) {
        
        Task {
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeWeekEventsWidgetViewModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getWeekEventsModel(from: now, range: range)
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
