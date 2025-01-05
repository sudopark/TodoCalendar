//
//  NextEventWidgetTimeLineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 1/5/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


struct NextEventWidgetTimeLineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<NextEventWidgetViewModel>
    
    init() { }
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) { NextEventWidgetViewModel.sample }
    }
    
    func getSnapshot(in context: Context, completion: @Sendable @escaping (Entry) -> Void) {
        guard context.isPreview == false
        else {
            completion(
                .init(date: Date()) { NextEventWidgetViewModel.sample }
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
                    entries: [entry],
                    policy: .after(refreshTime ?? now.nextUpdateTime)
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
                let model = try await viewModelProvider.getNextEventModel(for: now)
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
