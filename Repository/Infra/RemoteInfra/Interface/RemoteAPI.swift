//
//  RemoteAPI.swift
//  RemoteInfraInterface
//
//  Created by sudo.park on 10/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Alamofire
import Prelude
import Optics
import KernelUtils


// MARK: - RemoteAPI

public enum RemoteAPIMethod: String {
    case get
    case post
    case patch
    case delete
    case put
}

public protocol RemoteAPI: AnyObject, Sendable {
    
    func request(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String: String]?,
        parameters: [String: Any]
    ) async throws -> Data
    
    func attach(listener: any AutenticatorTokenRefreshListener)
    
    func setup(credential: APICredential?)
}

extension RemoteAPI {
    
    public func request<T: Decodable>(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String: String]? = nil,
        parameters: [String: Any] = [:]
    ) async throws -> T {
        do {
            let data = try await self.request(
                method, endpoint, with: header, parameters: parameters
            )
            let decodeResult = try JSONDecoder().decode(T.self, from: data)
            return decodeResult
        }
        catch let afError as AFError where afError.isExplicitlyCancelledError {
            let cancelError = ServerErrorModel()
                |> \.code .~ .cancelled
            throw cancelError
        }
        catch {
            throw error
        }
    }
}
