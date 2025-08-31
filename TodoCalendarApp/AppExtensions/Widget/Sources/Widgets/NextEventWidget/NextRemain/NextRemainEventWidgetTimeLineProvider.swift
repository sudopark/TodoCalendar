//
//  NextRemainEventWidgetTimeLineProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/31/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


struct NextRemainEventWidgetTimeLineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<NextEventListWidgetViewModel>
    
    init() { }
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) { NextEventListWidgetViewModel.sample }
    }
    
    func getSnapshot(in context: Context, completion: @Sendable @escaping (Entry) -> Void) {
        guard context.isPreview == false
        else {
            completion(
                .init(date: Date()) { NextEventListWidgetViewModel.sample }
            )
            return
        }
        
        self.getEntry { entry in
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @Sendable @escaping (Timeline<Entry>) -> Void) {
        
        self.getEntry { entry in
            
            let now = Date()
            switch entry.result {
            case .success(let model):
                let refreshTime = model.refreshAfter.map {
                    max($0, now.addingTimeInterval(10))
                }
                let timeline = Timeline(
                    entries: [entry], policy: .after(refreshTime ?? now.nextUpdateTime)
                )
                completion(timeline)
                
            case .failure:
                let timeline = Timeline(
                    entries: [entry], policy: .after(now.nextUpdateTime)
                )
                completion(timeline)
            }
        }
    }
    
    private func getEntry(_ completion: @Sendable @escaping (Entry) -> Void) {
        
        Task {
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeNextEventModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getNextEventModels(for: now)
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
