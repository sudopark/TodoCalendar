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


struct EventListWidgetTimeLineProvider: IntentTimelineProvider {
    
    typealias Intent = EventListTypeSelectIntent
    typealias Entry = ResultTimelineEntry<EventListWidgetViewModel>
    
    init() { }
}

extension EventListWidgetTimeLineProvider {
    
    func placeholder(
        in context: Context
    ) -> ResultTimelineEntry<EventListWidgetViewModel> {
        let sample = EventListWidgetViewModel.sample(
            maxItemCount: context.family.preferedEventListItemCount
        )
        return .init(date: Date(), result: .success(sample))
    }
    
    func getSnapshot(
        for configuration: EventListTypeSelectIntent,
        in context: Context,
        completion: @escaping (ResultTimelineEntry<EventListWidgetViewModel>
        ) -> Void) {
        
        guard context.isPreview == false
        else {
            let sample = self.placeholder(in: context)
            completion(sample)
            return
        }
        
        getEntry(configuration.eventType, context) { entry in
            completion(entry)
        }
    }
    
    func getTimeline(
        for configuration: EventListTypeSelectIntent,
        in context: Context,
        completion: @escaping (Timeline<ResultTimelineEntry<EventListWidgetViewModel>>) -> Void
    ) {
        
        self.getEntry(configuration.eventType, context) { entry in
            let timeline = Timeline(
                entries: [entry], policy: .after(Date().nextUpdateTime)
            )
            completion(timeline)
        }
    }
    
    private func getEntry(
        _ selected: EvnetListType?,
        _ context: Context,
        _ completion: @escaping (Entry) -> Void
    ) {
        
        let tagId = AllEventTagId(selected)
        let count = context.family.preferedEventListItemCount
        Task {
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeEventListViewModelProvider(targetEventTagId: tagId)
            let now = Date()
            do {
                let model = try await viewModelProvider.getEventListViewModel(
                    for: now,
                    maxItemCount: count
                )
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

extension AllEventTagId {
    
    init(_ listType: EvnetListType?) {
        switch listType?.identifier {
        case "default": self = .default
        case .some(let value): self = .custom(value)
        default: self = .default
        }
    }
}


extension WidgetFamily {
    
    var preferedEventListItemCount: Int {
        switch self {
        case .systemSmall: return 3
        case .systemMedium: return 3
        case .systemLarge: return 6
        default: return 0
        }
    }
}
