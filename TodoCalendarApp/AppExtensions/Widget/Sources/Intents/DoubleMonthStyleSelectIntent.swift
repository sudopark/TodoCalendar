//
//  DoubleMonthStyleSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import AppIntents
import Domain


// MARK: - DoubleMonthStyleEntity

struct DoubleMonthStyleEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "WidgetStyle"
    static let defaultQuery = DoubleMonthStyleQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)")
    }
}

extension DoubleMonthStyleEntity {

    init(style: WidgetStyle) {
        self.init(id: style.id.style.entityId, name: style.displayName)
    }
}


// MARK: - DoubleMonthStyleQuery

/// 조회할 변형을 타입 안에 박으므로 위젯군마다 엔티티·쿼리가 따로 선다.
struct DoubleMonthStyleQuery: EntityQuery, @unchecked Sendable {

    private let factory: WidgetStyleIntentFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    /// 저장된 id 를 라벨로 복원한다 — 지워진 스타일은 목록에 없어 자연히 빠진다.
    func entities(for identifiers: [String]) async throws -> [DoubleMonthStyleEntity] {
        let selectedIds = Set(identifiers)
        return self.savedStyleEntities().filter { selectedIds.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DoubleMonthStyleEntity] {
        return self.savedStyleEntities()
    }

    private func savedStyleEntities() -> [DoubleMonthStyleEntity] {
        return self.factory.makeStyleUsecase()
            .loadStyles(of: .doubleMonthMedium)
            .map { DoubleMonthStyleEntity(style: $0) }
    }
}
