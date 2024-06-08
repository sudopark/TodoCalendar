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
            .prefixedEvents(context.family.preferedItemCount)
        return .init(date: Date(), result: .success(sample))
    }
    
    func getSnapshot(
        in context: Context,
        completion: @escaping (ResultTimelineEntry<EventListWidgetViewModel>
        ) -> Void) {
        
        guard context.isPreview == false
        else {
            let sample = EventListWidgetViewModel.sample()
                .prefixedEvents(context.family.preferedItemCount)
            completion(
                .init(date: Date()) { sample }
            )
            return
        }
        
        getEntry(withPrefixed: context.family.preferedItemCount) { entry in
            completion(entry)
        }
    }
    
    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ResultTimelineEntry<EventListWidgetViewModel>>) -> Void
    ) {
        
        self.getEntry(withPrefixed: context.family.preferedItemCount) { entry in
            let timeline = Timeline(
                entries: [entry], policy: .after(Date().nextUpdateTime)
            )
            completion(timeline)
        }
    }
    
    private func getEntry(withPrefixed count: Int, _ completion: @escaping (Entry) -> Void) {
        
        Task {
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeEventListViewModelProvider()
            let now = Date()
            do {
                let model = try await viewModelProvider.getEventListViewModel(for: now)
                        .prefixedEvents(count)
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


private extension WidgetFamily {
    
    var preferedItemCount: Int {
        switch self {
        case .systemSmall: return 3
        case .systemMedium: return 3
        case .systemLarge: return 6
        default: return 0
        }
    }
}

private extension EventListWidgetViewModel {
    
    func prefixedEvents(_ max: Int) -> EventListWidgetViewModel {
        
        var remain = max; var index = 0
        var days: [DayEventListModel] = []
        while index < self.lists.count && remain > 0 {
            let day = self.lists[index].prefixIfNeed(remain)
            if !day.events.isEmpty {
                days.append(day)
            }
            remain -= day.events.count
            index += 1
        }
        let totalEventCount = self.lists.flatMap { $0.events }.count
        return self
            |> \.lists .~ days
            |> \.needBottomSpace .~ (totalEventCount < max)
    }
}

private extension EventListWidgetViewModel.DayEventListModel {
    
    func prefixIfNeed(_ remainCount: Int) -> EventListWidgetViewModel.DayEventListModel {
        if self.events.count > remainCount {
            return self |> \.events %~ { Array($0.prefix(remainCount)) }
        } else {
            return self
        }
    }
}

