//
//  EventDetailRemote.swift
//  Repository
//
//  Created by sudo.park on 8/15/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


public protocol EventDetailRemote: Sendable {
    
    func loadDetail(_ id: String) async throws -> EventDetailData
    func saveDetail(_ detail: EventDetailData) async throws -> EventDetailData
    func removeDetail(_ id: String) async throws
}


public final class EventDetailRemoteImple: EventDetailRemote {
    
    private let remoteAPI: any RemoteAPI
    public init(remoteAPI: any RemoteAPI) {
        self.remoteAPI = remoteAPI
    }
}

extension EventDetailRemoteImple {
    
    public func loadDetail(
        _ id: String
    ) async throws -> EventDetailData {
        let endpoint: EventDetailEndpoints = .detail(eventId: id)
        let mapper: EventDetailDataMapper = try await self.remoteAPI.request(
            .get, endpoint
        )
        return mapper.data
    }
    
    public func saveDetail(
        _ detail: EventDetailData
    ) async throws -> EventDetailData {
        let endpoint: EventDetailEndpoints = .detail(eventId: detail.eventId)
        let payload = detail.asJson()
        let mapper: EventDetailDataMapper = try await self.remoteAPI.request(
            .put,
            endpoint,
            parameters: payload
        )
        return mapper.data
    }
    
    public func removeDetail(_ id: String) async throws {
        let endpoint: EventDetailEndpoints = .detail(eventId: id)
        let _: RemoveTodoResultMapper = try await self.remoteAPI.request(
            .delete,
            endpoint
        )
    }
}
