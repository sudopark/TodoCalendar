//
//  StubRemoteAPI.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Domain
import Extensions
@testable import Repository


final class StubRemoteAPI: RemoteAPI, @unchecked Sendable {
    
    struct Response {
        let method: RemoteAPIMethod
        let endpoint: any Endpoint
        let header: [String: String]?
        let parameters: [String: Any]
        let parameterCompare: (([String: Any], [String: Any]) -> Bool)?
        let resultJsonString: Result<String, Error>
        
        init(
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
    init(responses: [Response]) {
        self.responses = responses
    }
    
    let environment: RemoteEnvironment = .init(
        calendarAPIHost: "dummy_calendar_api_host",
        csAPI: "cs_channel_api"
    )
    var didRequestedPath: String?
    var didRequestedParams: [String: Any]?
    var didRequestedPaths: [String] = []
    
    func attach(listener: any AutenticatorTokenRefreshListener) {
        
    }
    
    var credential: APICredential?
    func setup(credential: APICredential?) {
        self.credential = credential
    }
    
    var shouldFailRequest: Bool = false
    
    func request(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        with header: [String : String]?,
        parameters: [String : Any]
    ) async throws -> Data {
        
        guard self.shouldFailRequest == false
        else {
            throw RuntimeError("failed")
        }
        
        guard let path = environment.path(endpoint)
        else {
            throw RuntimeError("invalid params")
        }
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
