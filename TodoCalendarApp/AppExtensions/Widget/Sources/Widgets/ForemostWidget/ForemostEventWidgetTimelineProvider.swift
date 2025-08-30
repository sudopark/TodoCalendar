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
import CalendarScenes


struct ForemostEventWidgetTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<ForemostEventWidgetViewModel>
    init() { }
}

extension ForemostEventWidgetTimelineProvider {
    
    func placeholder(in context: Context) -> Entry {
        let sample = ForemostEventWidgetViewModel.sample()
        return .init(date: Date(), result: .success(sample))
    }
    
    func getSnapshot(in context: Context, completion: @Sendable @escaping (Entry) -> Void) {
        
        guard context.isPreview == false
        else {
            let sample = self.placeholder(in: context)
            completion(sample)
            return
        }
        
        self.getEntry(context) { entry in
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @Sendable @escaping (Timeline<Entry>) -> Void) {
        
        self.getEntry(context) { entry in
            let timeline = Timeline(
                entries: [entry], policy: .after(Date().nextUpdateTime)
            )
            completion(timeline)
        }
    }
    
    private func getEntry(_ context: Context, _  completion: @Sendable @escaping (Entry) -> Void) {
        
        let family = context.family
        Task {
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeForemostEventWidgetViewModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getViewModel(now)
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
