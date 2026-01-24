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
    private let isDoneTodoDetail: Bool
    public init(
        remoteAPI: any RemoteAPI,
        isDoneTodoDetail: Bool = false
    ) {
        self.remoteAPI = remoteAPI
        self.isDoneTodoDetail = isDoneTodoDetail
    }
}

extension EventDetailRemoteImple {
    
    private func endpoint(_ id: String) -> Endpoint {
        if self.isDoneTodoDetail {
            return EventDetailEndpoints.doneTodoDetail(eventId: id)
        } else {
            return EventDetailEndpoints.detail(eventId: id)
        }
    }
    
    public func loadDetail(
        _ id: String
    ) async throws -> EventDetailData {
        let endpoint = self.endpoint(id)
        let mapper: EventDetailDataMapper = try await self.remoteAPI.request(
            .get, endpoint
        )
        return mapper.data
    }
    
    public func saveDetail(
        _ detail: EventDetailData
    ) async throws -> EventDetailData {
        let endpoint = self.endpoint(detail.eventId)
        let payload = detail.asJson()
        let mapper: EventDetailDataMapper = try await self.remoteAPI.request(
            .put,
            endpoint,
            parameters: payload
        )
        return mapper.data
    }
    
    public func removeDetail(_ id: String) async throws {
        let endpoint = self.endpoint(id)
        let _: RemoveTodoResultMapper = try await self.remoteAPI.request(
            .delete,
            endpoint
        )
    }
}
