//
//  EventTypeSelectIntent.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/26/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit
import AppIntents
import Prelude
import Optics
import Domain
import Repository


// MARK: - EventTypeEntity

struct EventTypeEntity: AppEntity, Sendable {
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "EventType"
    
    var isDefaultTag: Bool = false
    var id: String
    
    var name: String
    
    var externalServiceId: String?
    var externalServiceName: String?
    
    static let defaultQuery = EventTypeQuery()
    
    var displayRepresentation: DisplayRepresentation {
        if let service = externalServiceName, !service.isEmpty {
            return DisplayRepresentation(
                title: "\(name)",
                subtitle: "\(service)"
            )
        } else {
            return DisplayRepresentation(
                title: "\(name)"
            )
        }
    }
}


// MARK: - EventTypeQuery

struct EventTypeQuery: EntityQuery, @unchecked Sendable {
    
    private let factory: EventTypeSelectIntentFactory
    
    init() {
        self.factory = .init(base: AppExtensionBase())
    }
    
    
    func entities(for identifiers: [String]) async throws -> [EventTypeEntity] {
        let allTags = try await self.loadAllOnTags()
        let entities = allTags.map(asEntity(_:))
        let selectIdSet = Set(identifiers)
        return entities.filter { selectIdSet.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [EventTypeEntity] {
        let allTags = try await self.loadAllOnTags()
        return allTags.map(asEntity(_:))
    }
    
    private func loadAllOnTags() async throws -> [Tags] {
        
        let tagRepository = self.factory.makeEventTagRepository()
        
        let baseTags = try await tagRepository.loadAllCustomTags()
            .values.first(where: { _ in true })?
            .map { Tags.custom($0) } ?? []
        let externalTags = try await self.loadOnGoogleCalendarTags()
        
        return [.defaultTag] + baseTags + externalTags
    }
    
    private func asEntity(_ tag: Tags) -> EventTypeEntity {
        switch tag {
        case .defaultTag:
            return EventTypeEntity(
                id: "default", name: "eventTag.defaults.default::name".localized()
            )
            |> \.isDefaultTag .~ true
            
        case .custom(let tag):
            return EventTypeEntity(id: tag.uuid, name: tag.name)
            
        case .google(let serviceId, let tag):
            return EventTypeEntity(id: tag.id, name: tag.name)
            |> \.externalServiceId .~ serviceId
            |> \.externalServiceName .~ "external_service.name::google".localized()
        }
    }
    
    private func loadOnGoogleCalendarTags() async throws -> [Tags] {
        
        let externalCalendarRepository = factory.makeExternalCalendarAcountRepository()
        let googleRepository = factory.makeGoogleCalendarRepository()
        
        let serviceId = GoogleCalendarService.id
        let externalAccounts = try await externalCalendarRepository.loadIntegratedAccounts().asDictionary { $0.serviceIdentifier }
        guard externalAccounts[serviceId] != nil else { return [] }
        
        let tags = try await googleRepository.loadCalendarTags().values
            .first(where: { _ in true })?
            .filter { !$0.isHoliday }
            .map { Tags.google(serviceId, $0) }
        return tags ?? []
    }
}

private enum Tags {
    case defaultTag
    case custom(CustomEventTag)
    case google(String, GoogleCalendar.Tag)
}


// MARK: - Intent


struct EventTypeSelectIntent: WidgetConfigurationIntent {
    
    static let title: LocalizedStringResource = ""
    
    @Parameter(title: "Event Types", default: nil)
    var eventTypes: [EventTypeEntity]?
}


struct EventListComponentSelectIntent: WidgetConfigurationIntent {
    
    static let title: LocalizedStringResource = ""
    
    @Parameter(title: "Event Types", default: nil)
    var eventTypes: [EventTypeEntity]?
    
    @Parameter(title: "Exclude all day event", default: false)
    var excludeAllDayEvent: Bool
}
