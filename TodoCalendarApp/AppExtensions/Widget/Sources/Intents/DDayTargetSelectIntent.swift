//
//  DDayTargetSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/29/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import AppIntents
import Prelude
import Optics
import Domain
import Extensions
import CalendarScenes


// MARK: - DDayTargetEventId + entity id

extension DDayTargetEventId {

    private static var todoPrefix: String { "todo::" }
    private static var schedulePrefix: String { "schedule::" }

    var entityId: String {
        let prefix = self.isTodo ? Self.todoPrefix : Self.schedulePrefix
        return "\(prefix)\(self.eventId)"
    }

    init?(entityId: String) {
        if entityId.hasPrefix(Self.todoPrefix) {
            self.init(
                eventId: String(entityId.dropFirst(Self.todoPrefix.count)), isTodo: true
            )
        } else if entityId.hasPrefix(Self.schedulePrefix) {
            self.init(
                eventId: String(entityId.dropFirst(Self.schedulePrefix.count)), isTodo: false
            )
        } else {
            return nil
        }
    }
}


// MARK: - DDayTargetEventEntity

struct DDayTargetEventEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Event"

    var id: String
    var name: String
    var dateText: String

    static let defaultQuery = DDayTargetEventQuery()

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)", subtitle: "\(dateText)")
    }
}


// MARK: - DDayTargetEventQuery

struct DDayTargetEventQuery: EntityQuery, @unchecked Sendable {

    private let factory: DDayTargetSelectIntentFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    private static var suggestionDays: Int { 365 }
    private static var suggestionLimit: Int { 50 }

    func entities(for identifiers: [String]) async throws -> [DDayTargetEventEntity] {

        let usecase = self.factory.makeEventFetchUsecase()
        let timeZone = self.factory.loadTimeZone()
        let now = Date()

        let targets = identifiers.compactMap { DDayTargetEventId(entityId: $0) }
        var entities: [DDayTargetEventEntity] = []
        for target in targets {
            guard let event = try? await usecase.fetchDDayTargetEvent(target, after: now)
            else { continue }
            entities.append(self.asEntity(event, timeZone))
        }
        return entities
    }

    func suggestedEntities() async throws -> [DDayTargetEventEntity] {

        let usecase = self.factory.makeEventFetchUsecase()
        let timeZone = self.factory.loadTimeZone()
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let now = Date()

        guard let todayStart = calendar.dayRange(now)?.lowerBound,
              let until = calendar.addDays(Self.suggestionDays, from: now)
        else { return [] }

        let events = try await usecase.fetchEvents(
            in: todayStart..<until.timeIntervalSince1970, timeZone
        )
        return self.asSuggestions(events.eventWithTimes, timeZone)
    }

    private func asSuggestions(
        _ events: [any CalendarEvent], _ timeZone: TimeZone
    ) -> [DDayTargetEventEntity] {

        let sorted = events
            .filter { !($0 is HolidayCalendarEvent) }
            .compactMap { event -> (DDayTargetEventId, String, EventTime)? in
                guard let time = event.eventTime else { return nil }
                switch event {
                case let todo as TodoCalendarEvent:
                    return (.init(eventId: todo.eventId, isTodo: true), todo.name, time)
                case let schedule as ScheduleCalendarEvent:
                    return (
                        .init(eventId: schedule.eventIdWithoutTurn, isTodo: false),
                        schedule.name, time
                    )
                default:
                    return nil
                }
            }
            .sorted { $0.2.lowerBoundWithFixed < $1.2.lowerBoundWithFixed }

        var seen = Set<DDayTargetEventId>()
        return sorted
            .filter { seen.insert($0.0).inserted }
            .prefix(Self.suggestionLimit)
            .map { targetId, name, time in
                DDayTargetEventEntity(
                    id: targetId.entityId,
                    name: name,
                    dateText: DDayTargetDateFormatter.text(of: time, in: timeZone)
                )
            }
    }

    private func asEntity(
        _ event: DDayTargetEvent, _ timeZone: TimeZone
    ) -> DDayTargetEventEntity {
        return DDayTargetEventEntity(
            id: event.targetId.entityId,
            name: event.name,
            dateText: DDayTargetDateFormatter.text(of: event.time, in: timeZone)
        )
    }
}


// MARK: - DDayTargetDateFormatter

enum DDayTargetDateFormatter {

    static func text(of time: EventTime, in timeZone: TimeZone) -> String {
        let date = Date(
            timeIntervalSince1970: time.rangeWithShifttingifNeed(on: timeZone).lowerBound
        )
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("yMMMdEEE")
        return formatter.string(from: date)
    }
}


// MARK: - Intent

struct DDayWidgetConfigurationIntent: WidgetConfigurationIntent {

    static let title: LocalizedStringResource = ""

    @Parameter(title: "Event", default: nil)
    var target: DDayTargetEventEntity?
}
