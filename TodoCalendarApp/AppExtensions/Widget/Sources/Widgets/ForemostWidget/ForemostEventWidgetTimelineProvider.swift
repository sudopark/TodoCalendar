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

struct ForemostEventWidgetViewModelWithSize {
    
    enum SupportSize {
        case circular
        case rectangular
        case inline
        case small
        case medium
        
        init(_ family: WidgetFamily) {
            switch family {
            case .accessoryCircular: self = .circular
            case .accessoryRectangular: self = .rectangular
            case .accessoryInline: self = .inline
            case .systemSmall: self = .small
            case .systemMedium: self = .medium
            default: self = .medium
            }
        }
    }
    
    let model: ForemostEventWidgetViewModel
    let size: SupportSize
}

struct ForemostEventWidgetTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<ForemostEventWidgetViewModelWithSize>
    init() { }
}

extension ForemostEventWidgetTimelineProvider {
    
    func placeholder(in context: Context) -> Entry {
        let sample = ForemostEventWidgetViewModel.sample()
        let model = ForemostEventWidgetViewModelWithSize(model: sample, size: .init(context.family))
        return .init(date: Date(), result: .success(model))
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
                let modelWithSize = ForemostEventWidgetViewModelWithSize(model: model, size: .init(family))
                completion(
                    .init(date: now, result: .success(modelWithSize))
                )
            } catch {
                completion(
                    .init(date: now, result: .failure(.init(error: error)))
                )
            }
        }
    }
}
