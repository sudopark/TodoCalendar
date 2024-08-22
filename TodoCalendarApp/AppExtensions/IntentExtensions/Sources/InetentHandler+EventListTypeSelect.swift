//
//  InetentHandler+EventListTypeSelect.swift
//  TodoCalendarAppIntentExtensions
//
//  Created by sudo.park on 7/27/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Intents
import Domain
import Extensions

extension IntentHandler: EventListTypeSelectIntentHandling {
    
    func provideEventTypeOptionsCollection(
        for intent: EventListTypeSelectIntent,
        searchTerm: String?
    ) async throws -> INObjectCollection<EvnetListType> {
        
        let factory = IntentReposiotryFactory(base: AppExtensionBase())
        let repository = factory.makeEventTagRepository()
        let allTags = try await repository.loadAllTags().values.first(where: { _ in true }) ?? []
        let defaultType = EvnetListType(identifier: "default", display: "All")
        let types = allTags.map {
            EvnetListType(identifier: $0.uuid, display: $0.name)
        }
        return INObjectCollection(items: [defaultType] + types)
    }
}

