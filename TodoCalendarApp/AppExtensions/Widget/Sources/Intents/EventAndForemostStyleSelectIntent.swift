//
//  EventAndForemostStyleSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import AppIntents
import Domain


// MARK: - EventAndForemostStyleEntity

struct EventAndForemostStyleEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "WidgetStyle"
    static let defaultQuery = EventAndForemostStyleQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)")
    }
}

extension EventAndForemostStyleEntity {

    init(style: WidgetStyle) {
        self.init(id: style.id.style.entityId, name: style.displayName)
    }
}


// MARK: - EventAndForemostStyleQuery

/// 조회할 변형을 타입 안에 박으므로 위젯군마다 엔티티·쿼리가 따로 선다.
struct EventAndForemostStyleQuery: EntityQuery, @unchecked Sendable {

    private let factory: WidgetStyleIntentFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    /// 저장된 id 를 라벨로 복원한다 — 지워진 스타일은 목록에 없어 자연히 빠진다.
    func entities(for identifiers: [String]) async throws -> [EventAndForemostStyleEntity] {
        let selectedIds = Set(identifiers)
        return self.savedStyleEntities().filter { selectedIds.contains($0.id) }
    }

    func suggestedEntities() async throws -> [EventAndForemostStyleEntity] {
        return self.savedStyleEntities()
    }

    private func savedStyleEntities() -> [EventAndForemostStyleEntity] {
        return self.factory.makeStyleUsecase()
            .loadStyles(of: .eventAndForemostMedium)
            .map { EventAndForemostStyleEntity(style: $0) }
    }
}
