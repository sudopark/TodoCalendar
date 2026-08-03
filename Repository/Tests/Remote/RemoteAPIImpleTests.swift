//
//  RemoteAPIImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/10/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
@testable import Alamofire
import Domain
import UnitTestHelpKit

@testable import Repository


class RemoteAPIImpleTests {
    
    private func makeRemote(
        session: FakeSession = FakeSession(),
        acceptLanguage: @escaping @Sendable () -> String = { "en" }
    ) -> RemoteAPIImple {
        let env = RemoteEnvironment(
            calendarAPIHost: "https://fake.com",
            csAPI: "some",
            deviceId: "device_id",
            acceptLanguage: acceptLanguage
        )
        return RemoteAPIImple(session: session, environment: env, interceptor: nil)
    }
}

extension RemoteAPIImpleTests {
    
    @Test func remote_cancel_request() async throws {
        // given
        let remote = self.makeRemote()
        
        // when
        let endpoint = EventSyncEndPoints.check
        let task = Task {
            let data = try await remote.request(.get, endpoint, with: [:], parameters: [:])
            return data
        }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        
        // then
        let result = await task.result
        if case .explicitlyCancelled  = result.failure as? AFError {
            #expect(true)
        } else {
            Issue.record("기대한 응답이 아님")
        }
    }
    
    @Test func remote_whenCancel_beforePerform() async throws {
        // given
        let remote = self.makeRemote()

        // when
        let endpoint = EventSyncEndPoints.check
        let task = Task {
            let data = try await remote.request(.get, endpoint, with: [:], parameters: [:])
            return data
        }
        task.cancel()

        // then
        let result = await task.result
        #expect(result.failure is CancellationError)
    }

    @Test func remote_request_attachesAcceptLanguageHeaderFromEnvironment() async throws {
        // given
        let session = FakeSession()
        let remote = self.makeRemote(session: session, acceptLanguage: { "ko-KR,en-US;q=0.9" })

        // when
        let task = Task {
            try await remote.request(.get, EventSyncEndPoints.check, with: [:], parameters: [:])
        }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        _ = await task.result

        // then
        #expect(session.didRequestedHeaders?["Accept-Language"] == "ko-KR,en-US;q=0.9")
    }
}

private final class FakeSession: Session, @unchecked Sendable {

    var didRequestedHeaders: HTTPHeaders?

    override func request(
        _ convertible: any URLConvertible,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: any ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil,
        interceptor: (any RequestInterceptor)? = nil,
        requestModifier: Session.RequestModifier? = nil
    ) -> DataRequest {

        self.didRequestedHeaders = headers
        let req = RequestConvertible(url: convertible, method: method, parameters: parameters, encoding: encoding, headers: headers, requestModifier: requestModifier)
        
        let request = DataRequest(
            convertible: req, underlyingQueue: .main, serializationQueue: .main, eventMonitor: nil, interceptor: interceptor, delegate: self
        )
        
        return request
    }
}
