//
//  StubRemoteAPI.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/06/11.
//

import Foundation
import Extensions
@testable import Repository


final class StubRemoteAPI: RemoteAPI {
    
    struct Resopnse {
        let method: RemoteAPIMethod
        let path: String
        let header: [String: String]?
        let parameters: [String: Any]
        let parameterCompare: (([String: Any], [String: Any]) -> Bool)?
        let resultJsonString: Result<String, Error>
        
        init(
            method: RemoteAPIMethod = .get,
            path: String,
            header: [String : String]? = nil,
            parameters: [String : Any] = [:],
            parameterCompare: (([String: Any], [String: Any]) -> Bool)? = nil,
            resultJsonString: Result<String, Error>
        ) {
            self.method = method
            self.path = path
            self.header = header
            self.parameters = parameters
            self.parameterCompare = parameterCompare
            self.resultJsonString = resultJsonString
        }
    }
    
    private let responses: [Resopnse]
    init(responses: [Resopnse]) {
        self.responses = responses
    }
    
    func request(
        _ method: RemoteAPIMethod,
        path: String,
        with header: [String : String]?,
        parameters: [String : Any]
    ) async throws -> Data {
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
    ) -> Resopnse? {
        
        return self.responses.first(where: { response in
            return response.method == method
            && response.path == path
            && response.header == header
            && response.parameterCompare.map { $0(response.parameters, parameters) } ?? true
        })
    }
}
