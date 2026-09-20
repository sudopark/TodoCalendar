//
//  DDayStyleSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import AppIntents
import Domain


// MARK: - DDayStyleEntity

struct DDayStyleEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "WidgetStyle"
    static let defaultQuery = DDayStyleQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)")
    }
}

extension DDayStyleEntity {

    init(style: WidgetStyle) {
        self.init(id: style.id.style.entityId, name: style.displayName)
    }
}


// MARK: - DDayStyleQuery

struct DDayStyleQuery: EntityQuery, @unchecked Sendable {

    private let factory: WidgetStyleIntentFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    func entities(for identifiers: [String]) async throws -> [DDayStyleEntity] {
        let selectedIds = Set(identifiers)
        return self.savedStyleEntities().filter { selectedIds.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DDayStyleEntity] {
        return self.savedStyleEntities()
    }

    private func savedStyleEntities() -> [DDayStyleEntity] {
        return self.factory.makeStyleUsecase()
            .loadStyles(of: .ddaySmall)
            .map { DDayStyleEntity(style: $0) }
    }
}
