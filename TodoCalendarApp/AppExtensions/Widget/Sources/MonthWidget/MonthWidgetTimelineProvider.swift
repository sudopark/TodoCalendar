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
    
    private let viewModelProvider: any MonthWidgetViewModelProvider
    
    init(
        viewModelProvider: any MonthWidgetViewModelProvider
    ) {
        self.viewModelProvider = viewModelProvider
    }
    
    func placeholder(in context: Context) -> Entry {
        let now = Date()
        return .init(date: now) {
            try self.viewModelProvider.makeSampleMonthViewModel(now)
        }
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(self.placeholder(in: context))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
     
        self.getEntity { entity in
            let timeline = Timeline(
                entries: [entity],
                policy: .after(Date().nextUpdateTime)
            )
            completion(timeline)
        }
    }
    
    private func getEntity(_ completion: @escaping (Entry) -> Void) {
        
        Task {
            
            let now = Date()
            do {
                let model = try await self.viewModelProvider.getMonthViewModel(now)
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
