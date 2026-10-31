//
//  StubRemoteAPI.swift
//  RemoteInfraTesting
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Extensions
import RemoteInfraInterface


public final class StubRemoteAPI: RemoteAPI, @unchecked Sendable {
    
    public struct Response {
        public let method: RemoteAPIMethod
        public let endpoint: any Endpoint
        public let header: [String: String]?
        public let parameters: [String: Any]
        public let parameterCompare: (([String: Any], [String: Any]) -> Bool)?
        public let resultJsonString: Result<String, Error>
        
        public init(
            method: RemoteAPIMethod = .get,
            endpoint: any Endpoint,
            header: [String : String]? = nil,
            parameters: [String : Any] = [:],
            parameterCompare: (([String: Any], [String: Any]) -> Bool)? = nil,
            resultJsonString: Result<String, Error>
        ) {
            self.method = method
            self.endpoint = endpoint
            self.header = header
            self.parameters = parameters
            self.parameterCompare = parameterCompare
            self.resultJsonString = resultJsonString
        }
    }
    
    private let responses: [Response]
    public init(responses: [Response]) {
        self.responses = responses
    }
    
    public let environment: RemoteEnvironment = .init(
        calendarAPIHost: "dummy_calendar_api_host",
        csAPI: "cs_channel_api",
        deviceId: "device_id",
        acceptLanguage: { "en" }
    )
    public var didRequestedMethod: RemoteAPIMethod?
    public var didRequestedPath: String?
    public var didRequestedParams: [String: Any]?
    public var didRequestedPaths: [String] = []
    
    public func attach(listener: any AutenticatorTokenRefreshListener) {
        
    }
    
    public var credential: APICredential?
    public func setup(credential: APICredential?) {
        self.credential = credential
    }
    
    public var shouldFailRequest: Bool = false
    
    public func request(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String : String]?,
        parameters: [String : Any]
    ) async throws -> Data {
        
        guard self.shouldFailRequest == false
        else {
            throw RuntimeError("failed")
        }
        
        let path = environment.path(endpoint)
        self.didRequestedMethod = method
        self.didRequestedPath = path
        self.didRequestedPaths.append(path)
        self.didRequestedParams = parameters
        
        guard let response = self.findResponse(method: method, path: path, header: header, parameters: parameters)
        else {
            throw RuntimeError("no stub response exists")
        }
        let result = response.resultJsonString
        switch result {
        case .success(let text):
            guard let data = text.data(using: .utf8)
            else {
                throw RuntimeError("invalid response format")
            }
            return data
            
        case .failure(let error):
            throw error
        }
    }
    
    private func findResponse(
        method: RemoteAPIMethod,
        path: String,
        header: [String: String]?,
        parameters: [String: Any]
    ) -> Response? {
        
        return self.responses.first(where: { response in
            return response.method == method
            && self.environment.path(response.endpoint) == path
            && response.header == header
            && response.parameterCompare.map { $0(response.parameters, parameters) } ?? true
        })
    }
}
