//
//  WeekEventsStyleSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/18/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import AppIntents
import Domain
import Extensions


// MARK: - WeekEventsStyleEntity

struct WeekEventsStyleEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "WidgetStyle"
    static let defaultQuery = WeekEventsStyleQuery()

    var id: String
    var name: String
    var isSelectable: Bool = true

    var displayRepresentation: DisplayRepresentation {
        guard self.isSelectable else {
            let locked = "widget.style.candidate::locked".localized()
            return DisplayRepresentation(title: "\(name)", subtitle: "\(locked)")
        }
        return DisplayRepresentation(title: "\(name)")
    }
}

extension WeekEventsStyleEntity {

    init(style: WidgetStyle, isSelectable: Bool = true) {
        self.init(id: style.id.style.entityId, name: style.displayName, isSelectable: isSelectable)
    }
}


// MARK: - WeekEventsStyleQuery

/// 7변형이 좌표 하나를 공유하므로 대표 변형으로 조회한다 — 어느 변형에서 열어도 같은 목록이다.
struct WeekEventsStyleQuery: EntityQuery, @unchecked Sendable {

    private let factory: WidgetUsecaseFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    func entities(for identifiers: [String]) async throws -> [WeekEventsStyleEntity] {
        let selectedIds = Set(identifiers)
        return self.candidateEntities().filter { selectedIds.contains($0.id) }
    }

    func suggestedEntities() async throws -> [WeekEventsStyleEntity] {
        return self.candidateEntities()
    }

    private func candidateEntities() -> [WeekEventsStyleEntity] {
        return self.factory.makeWidgetStyleFetchUsecase()
            .fetchStyleCandidates(of: .oneWeekEvents)
            .map { WeekEventsStyleEntity(style: $0.style, isSelectable: $0.isSelectable) }
    }
}
