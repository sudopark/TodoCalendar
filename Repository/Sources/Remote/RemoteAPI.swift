//
//  RemoteAPI.swift
//  Repository
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Alamofire
import Prelude
import Optics
import Domain
import Extensions


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


// MARK: - RemoteAPIImple


public final class RemoteAPIImple: RemoteAPI, @unchecked Sendable {
 
    private let environment: RemoteEnvironment
    private let session: Session
    private let interceptor: (any APIRequestInterceptor)?
    
    public init(
        session: Session,
        environment: RemoteEnvironment,
        interceptor: (any APIRequestInterceptor)?
    ) {
        self.session = session
        self.environment = environment
        self.interceptor = interceptor
    }
}

extension RemoteAPIImple {
    
    public func attach(listener: AutenticatorTokenRefreshListener) {
        self.interceptor?.attach(listener: listener)
    }
    
    public func setup(credential: APICredential?) {
        
        self.interceptor?.update(credential: credential)
    }
    
    public func request(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String : String]?,
        parameters: [String : Any]
    ) async throws -> Data {
        
        try Task.checkCancellation()
        
        guard let path = self.environment.path(endpoint)
        else {
            throw RuntimeError("not support endpoint: \(endpoint)")
        }
        
        let shouldAdapt = self.interceptor?.shouldAdapt(endpoint) ?? false
        
        let dataTask = self.session.request(
            path,
            method: method.asHttpMethod(),
            parameters: parameters,
            encoding: method.encoding(),
            headers: header.map { HTTPHeaders($0) },
            interceptor: shouldAdapt ? self.interceptor : nil
        )
        .validate()
        .serializingData()

        let response = await dataTask.response
        let result = response.result
        switch result {
        case .success(let data):
            return data
        case .failure(let error):
            if var serverError = response.data
                .flatMap ({try? JSONDecoder().decode(ServerErrorModel.self, from: $0)}) {
                serverError.rawError = error
                serverError.statusCode = response.response?.statusCode ?? -1
                throw serverError
            } else {
                throw error
            }
        }
    }
}

extension RemoteAPIMethod {
    
    func asHttpMethod() -> HTTPMethod {
        switch self {
        case .get: return .get
        case .post: return .post
        case .patch: return .patch
        case .delete: return .delete
        case .put: return .put
        }
    }
    
    func encoding() -> any ParameterEncoding {
        switch self {
        case .post, .patch, .put: return JSONEncoding.default
        default: return URLEncoding(arrayEncoding: .noBrackets, boolEncoding: .literal)
        }
    }
}
