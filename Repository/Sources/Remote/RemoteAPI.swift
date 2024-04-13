//
//  RemoteAPI.swift
//  Repository
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Alamofire
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
    
    func attach(listener: any OAuthAutenticatorTokenRefreshListener)
    
    func setup(
        credential auth: Auth?
    )
}

extension RemoteAPI {
    
    public func request<T: Decodable>(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String: String]? = nil,
        parameters: [String: Any] = [:]
    ) async throws -> T {
        let data = try await self.request(
            method, endpoint, with: header, parameters: parameters
        )
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


public final class RemoteAPIImple: RemoteAPI, @unchecked Sendable {
 
    private let environment: RemoteEnvironment
    private let session: Session
    private let authenticator: OAuthAutenticator
    
    public init(
        environment: RemoteEnvironment,
        authenticator: OAuthAutenticator
    ) {
        self.environment = environment
        self.authenticator = authenticator
        
        let configure = URLSessionConfiguration.af.default
        configure.timeoutIntervalForRequest = 30
        self.session = Session(
            configuration: configure,
            serializationQueue: DispatchQueue(label: "af.serialization", qos: .utility),
            interceptor: AuthenticationInterceptor(authenticator: authenticator)
        )
    }
}

extension RemoteAPIImple {
    
    public func attach(listener: OAuthAutenticatorTokenRefreshListener) {
        self.authenticator.listener = listener
    }
    
    public func setup(credential auth: Auth?) {
        let credential: OptionalAuthCredential = auth.map { .need($0) } ?? .notNeed
        (self.session.interceptor as? AuthenticationInterceptor<OAuthAutenticator>)?.credential = credential
    }
    
    public func request(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String : String]?,
        parameters: [String : Any]
    ) async throws -> Data {
        
        guard let path = self.environment.path(endpoint)
        else {
            throw RuntimeError("not support endpoint: \(endpoint)")
        }
        
        let dataTask = self.session.request(
            path,
            method: method.asHttpMethod(),
            parameters: parameters,
            encoding: method.encoding(),
            headers: header.map { HTTPHeaders($0) }
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
        case .post, .patch: return JSONEncoding.default
        default: return URLEncoding(arrayEncoding: .noBrackets)
        }
    }
}
