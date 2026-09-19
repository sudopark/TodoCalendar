//
//  EventAndForemostWidgetTimelineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 4/13/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation
import WidgetScenes


struct EventAndForemostWidgetViewModelProvider {
    
    private let eventListViewModelProvider: EventListWidgetViewModelProvider
    private let foremostEventViewModelProvider: ForemostEventWidgetViewModelProvider
    
    init(
        eventListViewModelProvider: EventListWidgetViewModelProvider,
        foremostEventViewModelProvider: ForemostEventWidgetViewModelProvider
    ) {
        self.eventListViewModelProvider = eventListViewModelProvider
        self.foremostEventViewModelProvider = foremostEventViewModelProvider
    }
    
    func getViewModel(_ time: Date) async throws -> EventAndForemostWidgetViewModel {
        let eventList = try await self.eventListViewModelProvider.getEventListViewModel(
            for: time, widgetSize: .small
        )
        let foremost = try await self.foremostEventViewModelProvider.getViewModel(time)
        // 판과 두 절반의 글자색이 한 값에서 나와야 한다 — 하위 위젯군의 기본 스타일을 절반씩 물려받으면
        // 검은 판 위에 흰 배경용 글자색이 얹힌다. 합성 위젯의 배경색은 제 스타일 소관이다.
        let look = WidgetLook(globalSetting: eventList.look.globalSetting)
        return .init(event: eventList, foremost: foremost)
            |> \.event.look .~ look
            |> \.foremost.look .~ look
    }
}


struct EventAndForemostWidgetViewTimelineProvider: TimelineProvider {
    
    typealias Entry = ResultTimelineEntry<EventAndForemostWidgetViewModel>
    
    func placeholder(
        in context: Context
    ) -> ResultTimelineEntry<EventAndForemostWidgetViewModel> {
        
        return .init(date: Date()) {
            .init(
                event: EventListWidgetViewModel.sample(size: .small),
                foremost: ForemostEventWidgetViewModel.sample()
            )
        }
    }
    
    func getSnapshot(
        in context: Context,
        completion: @Sendable @escaping (ResultTimelineEntry<EventAndForemostWidgetViewModel>
        ) -> Void) {
        
        guard context.isPreview == false
        else {
            completion(placeholder(in: context))
            return
        }
        self.getEntry(context) { entry in
            completion(entry)
        }
    }
    
    func getTimeline(
        in context: Context,
        completion: @Sendable @escaping (Timeline<ResultTimelineEntry<EventAndForemostWidgetViewModel>>) -> Void
    ) {
        self.getEntry(context) { entry in
            let timeline = Timeline(entries: [entry], policy: .after(Date().nextUpdateTime))
            completion(timeline)
        }
    }
    
    private func getEntry(
        _ context: Context,
        _ completion: @Sendable @escaping (Entry) -> Void
    ) {
        
        Task {
            
            let builder = WidgetViewModelProviderBuilder(base: .init())
            let viewModelProvider = await builder.makeEventListAndForemostWidgetViewModelProvider(
                targetEventTagId: .default
            )
            let now = Date()
            do {
                let model = try await viewModelProvider.getViewModel(now)
                completion(
                    .init(date: now, result: .success(model))
                    |> \.background .~ model.event.look.background
                )
            } catch {
                completion(.init(date: now, result: .failure(.init(error: error))))
            }
        }
    }
}
