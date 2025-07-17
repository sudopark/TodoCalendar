//
//  EventSync+Mapping.swift
//  Repository
//
//  Created by sudo.park on 7/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


struct EventSyncTimeStampMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case dataType
        case timestamp
    }
    let timestamp: EventSyncTimestamp
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.timestamp = .init(
            try container.decode(SyncDataType.self, forKey: .dataType),
            try container.decode(Int.self, forKey: .timestamp)
        )
    }
}


struct EventSyncCheckResposeMapper: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case result
        case startTimestamp = "start"
    }
    
    var response: EventSyncCheckRespose
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.response = .init(
            result: try container.decode(EventSyncCheckRespose.CheckResult.self, forKey: .result)
        )
        self.response.startTimestamp = try? container.decode(Int.self, forKey: .startTimestamp)
    }
}

struct EventSyncResponseMapper<T: Sendable>: Decodable {
    
    private enum CodingKeys: String, CodingKey {
        case created
        case updated
        case deleted
        case nextPageCursor
        case newSyncTime
    }
    
    var response: EventSyncResponse<T>
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.response = .init()
        response.newSyncTime = (try? container.decode(EventSyncTimeStampMapper.self, forKey: .newSyncTime))?.timestamp
        response.nextPageCursor = try? container.decode(String.self, forKey: .nextPageCursor)
        switch T.self {
        case is CustomEventTag.Type:
            response.created = (try? container.decode([CustomEventTagMapper].self, forKey: .created))?.map { $0.tag }.compactMap { $0 as? T }
            response.updated = (try? container.decode([CustomEventTagMapper].self, forKey: .updated))?.map { $0.tag }.compactMap { $0 as? T }
            
        case is TodoEvent.Type:
            response.created = (try? container.decode([TodoEventMapper].self, forKey: .created))?.map { $0.todo }.compactMap { $0 as? T }
            response.updated = (try? container.decode([TodoEventMapper].self, forKey: .updated))?.map { $0.todo }.compactMap { $0 as? T }
            
        case is ScheduleEvent.Type:
            response.created = (try? container.decode([ScheduleEventMapper].self, forKey: .created))?.map { $0.event }.compactMap { $0 as? T }
            response.updated = (try? container.decode([ScheduleEventMapper].self, forKey: .updated))?.map { $0.event }.compactMap { $0 as? T }
            
        default: break
        }
        
        response.deletedIds = try? container.decode([String].self, forKey: .deleted)
    }
}
