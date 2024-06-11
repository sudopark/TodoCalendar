//
//  TodayWidgetTimelineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/12/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


struct TodayWidgetTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<TodayWidgetViewModel>
    
    func placeholder(in context: Context) -> ResultTimelineEntry<TodayWidgetViewModel> {
        let now = Date()
        return .init(date: now) { TodayWidgetViewModel.sample() }
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ResultTimelineEntry<TodayWidgetViewModel>) -> Void) {
        
        guard context.isPreview == false
        else {
            completion(
                .init(date: Date()) { TodayWidgetViewModel.sample() }
            )
            return
        }
        self.getEntry { entry in
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ResultTimelineEntry<TodayWidgetViewModel>>) -> Void) {
        
        self.getEntry { entry in
            let timeline = Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
            completion(timeline)
        }
    }
    
    private func getEntry(_ completion: @escaping (Entry) -> Void) {
        
        Task {
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeTodayViewModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getTodayViewModel(for: now)
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
