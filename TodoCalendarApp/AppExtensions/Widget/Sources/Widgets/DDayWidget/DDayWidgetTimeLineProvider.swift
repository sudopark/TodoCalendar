//
//  DDayWidgetTimeLineProvider.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions


struct DDayWidgetTimeLineProvider: AppIntentTimelineProvider {

    typealias Intent = DDayWidgetConfigurationIntent
    typealias Entry = ResultTimelineEntry<DDayWidgetViewModel>

    init() { }
}

extension DDayWidgetTimeLineProvider {

    func placeholder(in context: Context) -> Entry {
        return .init(date: Date(), result: .success(.sample))
    }

    func snapshot(
        for configuration: DDayWidgetConfigurationIntent, in context: Context
    ) async -> Entry {

        guard context.isPreview == false
        else {
            return self.placeholder(in: context)
        }
        return await self.loadEntry(configuration.target)
    }

    func timeline(
        for configuration: DDayWidgetConfigurationIntent, in context: Context
    ) async -> Timeline<Entry> {

        let entry = await self.loadEntry(configuration.target)
        let refreshAfter = (try? entry.result.get())?.refreshAfter
        return Timeline(
            entries: [entry],
            policy: .after(refreshAfter ?? Date().nextUpdateTime)
        )
    }

    private func loadEntry(_ selected: DDayTargetEventEntity?) async -> Entry {

        let target = selected.flatMap { DDayTargetEventId(entityId: $0.id) }
        let builder = WidgetViewModelProviderBuilder(base: .init())
        let viewModelProvider = await builder.makeDDayWidgetViewModelProvider()
        let now = Date()
        do {
            let model = try await viewModelProvider.getDDayModel(for: now, target: target)
            return .init(date: now, result: .success(model))
                |> \.background .~ model.widgetSetting.background
        } catch {
            return .init(date: now, result: .failure(.init(error: error)))
        }
    }
}
