//
//  MonthWidgetTimelineProvider.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/19/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes



struct MonthWidgetTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<MonthWidgetViewModel>
    
    init() { }
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) {
            try MonthWidgetViewModel.makeSample()
        }
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        guard context.isPreview == false
        else {
            completion(
                .init(date: Date()) { try MonthWidgetViewModel.makeSample() }
            )
            return
        }
        self.getEntry { entry in
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
     
        self.getEntry { entry in
            let timeline = Timeline(
                entries: [entry],
                policy: .after(Date().nextUpdateTime)
            )
            completion(timeline)
        }
    }
    
    private func getEntry(_ completion: @escaping (Entry) -> Void) {
        
        let viewModelProvider = WidgetViewModelProviderBuilder.makeMonthViewModelProvider()
        Task {
            let now = Date()
            do {
                let model = try await viewModelProvider.getMonthViewModel(now)
                completion(
                    .init(date: now, result: .success(model))
                )
            } catch {
                completion(.init(
                    date: now, result: .failure(.init(error: error)))
                )
            }
        }
    }
}
