//
//  TodayStyleSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import AppIntents
import Domain


// MARK: - WidgetStyleId.Style + entity id

/// 저장소 키와 철자가 같아도 별개 계약이다 — 이 값은 위젯 인스턴스에 영속된다.
extension WidgetStyleId.Style {

    private enum Constant {
        static let defaultId: String = "default"
        static let customPrefix: String = "custom::"
    }

    var entityId: String {
        switch self {
        case .default: return Constant.defaultId
        case .custom(let id): return "\(Constant.customPrefix)\(id)"
        }
    }

    init?(entityId: String) {
        switch entityId {
        case Constant.defaultId:
            self = .default

        case let text where text.hasPrefix(Constant.customPrefix):
            let id = String(text.dropFirst(Constant.customPrefix.count))
            guard id.isEmpty == false else { return nil }
            self = .custom(id: id)

        default:
            return nil
        }
    }
}


// MARK: - TodayStyleEntity

struct TodayStyleEntity: AppEntity, Sendable {

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "WidgetStyle"
    static let defaultQuery = TodayStyleQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)")
    }
}

extension TodayStyleEntity {

    init(style: WidgetStyle) {
        self.init(id: style.id.style.entityId, name: style.displayName)
    }
}


// MARK: - TodayStyleQuery

struct TodayStyleQuery: EntityQuery, @unchecked Sendable {

    private let factory: TodayStyleSelectIntentFactory

    init() {
        self.factory = .init(base: AppExtensionBase())
    }

    /// 저장된 id 를 라벨로 복원한다 — 지워진 스타일은 목록에 없어 자연히 빠진다.
    func entities(for identifiers: [String]) async throws -> [TodayStyleEntity] {
        let selectedIds = Set(identifiers)
        return self.savedStyleEntities().filter { selectedIds.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TodayStyleEntity] {
        return self.savedStyleEntities()
    }

    private func savedStyleEntities() -> [TodayStyleEntity] {
        return self.factory.makeStyleUsecase()
            .loadStyles(of: .todaySummarySmall)
            .map { TodayStyleEntity(style: $0) }
    }
}
