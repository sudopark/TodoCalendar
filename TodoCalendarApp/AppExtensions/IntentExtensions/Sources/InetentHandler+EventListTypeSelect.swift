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
        let tagRepository = factory.makeEventTagRepository()
        let externalCalendarRepository = factory.makeExternalCalendarAcountRepository()
        let googleRepository = factory.makeGoogleCalendarRepository()
        
        var allTags: [Tags] = []
        for try await ts in tagRepository.loadAllCustomTags().values {
            allTags = ts.map { .custom($0) }
        }
        let googleServiceId = GoogleCalendarService.id
        let externalAccount = try await externalCalendarRepository.loadIntegratedAccounts().asDictionary { $0.serviceIdentifier }
        if externalAccount[googleServiceId] != nil {
            let externalTags = try await googleRepository.loadCalendarTags().values
                .first(where: { _ in true })?
                .filter { !$0.isHoliday }
                .map { Tags.external(googleServiceId, $0) } ?? []
            allTags += externalTags
        }
        
        let defaultType = EvnetListType(identifier: "default", display: "All")
        let types = allTags.map {
            switch $0 {
            case .custom(let tag):
                return EvnetListType(identifier: tag.uuid, display: tag.name)
            case .external(let serviceId, let tag):
                return EvnetListType(identifier: "external::\(serviceId)::\(tag.id)", display: tag.name)
            }
        }
        return INObjectCollection(items: [defaultType] + types)
    }
}

private enum Tags {
    case custom(CustomEventTag)
    case external(String, GoogleCalendar.Tag)
}
