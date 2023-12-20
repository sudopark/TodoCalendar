//
//  RemoteAPI.swift
//  Repository
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Alamofire


// MARK: - RemoteAPI

public enum RemoteAPIMethod: String {
    case get
    case post
    case path
    case delete
}

public protocol RemoteAPI: AnyObject, Sendable {
    
    func request(
        _ method: RemoteAPIMethod,
        path: String,
        with header: [String: String]?,
        parameters: [String: Any]
    ) async throws -> Data
}

extension RemoteAPI {
    
    public func request<T: Decodable>(
        _ method: RemoteAPIMethod,
        path: String,
        with header: [String: String]? = nil,
        parameters: [String: Any] = [:]
    ) async throws -> T {
        let data = try await self.request(method, path: path, with: header, parameters: parameters)
        do {
            let decodeResult = try JSONDecoder().decode(T.self, from: data)
            return decodeResult
        } catch {
            // TOOD: log error..
            throw error
        }
    }
}


// MARK: - RemoteAPIImple

private let underlyingSession = Session(
    serializationQueue: DispatchQueue(label: "af.serialization", qos: .utility)
)

public final class RemoteAPIImple: RemoteAPI, Sendable {
    
    private var session: Session {
        return underlyingSession
    }
    
    public init() {}
}

extension RemoteAPIImple {
    
    public func request(
        _ method: RemoteAPIMethod,
        path: String,
        with header: [String : String]?,
        parameters: [String : Any]
    ) async throws -> Data {
        let dataTask = self.session.request(
            path,
            method: method.asHttpMethod(),
            parameters: parameters,
            encoding: method.encoding(),
            headers: header.map { HTTPHeaders($0) }
        ).serializingData()
        
        let response = await dataTask.response
        let code = response.response?.statusCode ?? -1
        let result = response.result
        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}

extension RemoteAPIMethod {
    
    func asHttpMethod() -> HTTPMethod {
        switch self {
        case .get: return .get
        case .post: return .post
        case .path: return .patch
        case .delete: return .delete
        }
    }
    
    func encoding() -> any ParameterEncoding {
        switch self {
        case .post, .path: return JSONEncoding.default
        default: return URLEncoding(arrayEncoding: .noBrackets)
        }
    }
}
