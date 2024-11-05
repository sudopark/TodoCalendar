//
//  PublisherWaitable.swift
//  UnitTestHelpKit
//
//  Created by sudo.park on 2023/03/25.
//

import XCTest
import Combine


public protocol PublisherWaitable: AnyObject {
    
    var cancelBag: Set<AnyCancellable>! { get set }
}


extension PublisherWaitable where Self: XCTestCase {
    
    public func waitOutputs<P: Publisher>(
        _ expect: XCTestExpectation,
        for source: P,
        timeout: TimeInterval = 0.001,
        _ action: (() -> Void)? = nil
    ) -> [P.Output] {
        // given
        var outputs: [P.Output] = []
        
        // when
        source
            .sink { _ in } receiveValue: { output in
                outputs.append(output)
                expect.fulfill()
            }
            .store(in: &self.cancelBag)
        action?()
        self.wait(for: [expect], timeout: timeout)
        
        // then
        return outputs
    }
    
    public func waitError<P: Publisher>(
        _ expect: XCTestExpectation,
        for source: P,
        timeout: TimeInterval = 0.001,
        _ action: (() -> Void)? = nil
    ) -> P.Failure? {
        // given
        var failure: P.Failure?
        
        // when
        source
            .sink(receiveCompletion: { completion in
                guard case let .failure(fail) = completion else { return }
                failure = fail
                expect.fulfill()
            }, receiveValue: { _ in })
            .store(in: &self.cancelBag)
        action?()
        self.wait(for: [expect], timeout: timeout)
        
        // then
        return failure
    }
    
    public func waitFirstOutput<P: Publisher>(
        _ expect: XCTestExpectation,
        for source: P,
        timeout: TimeInterval = 0.001,
        _ action: (() -> Void)? = nil
    ) -> P.Output? {
        return self.waitOutputs(expect, for: source, timeout: timeout, action).first
    }
}


// MARK: - Testing



import Testing



@available(iOS 16.0, *)
public final class ConfirmationExpectation {
    let comment: Comment?
    public var count: Int
    public var timeout: Duration
    
    init(comment: Comment?, count: Int, timeout: Duration) {
        self.comment = comment
        self.count = count
        self.timeout = timeout
    }
}

extension PublisherWaitable {
    
    @available(iOS 16.0, *)
    public func expectConfirm(
        _ description: String
    ) -> ConfirmationExpectation {
        return .init(comment: .init(stringLiteral: description), count: 1, timeout: .milliseconds(100))
    }

    @available(iOS 16.0, *)
    public func outputs<P: Publisher>(
        _ confirmExpect: ConfirmationExpectation,
        for source: P,
        _ action: (() -> Void)? = nil
    ) async throws -> [P.Output] where P.Output: Sendable {
        return try await confirmation(confirmExpect.comment, expectedCount: confirmExpect.count) { confirm in
            
            var sender: [P.Output] = []
            
            source
                .sink { _ in } receiveValue: { output in
                    sender.append(output)
                    confirm()
                }
                .store(in: &self.cancelBag)
            
            action?()
            
            try await Task.sleep(for: confirmExpect.timeout)
            return sender
        }
    }
 
    @available(iOS 16.0, *)
    public func firstOutput<P: Publisher>(
        _ confirmExpect: ConfirmationExpectation,
        for source: P,
        _ action: (() -> Void)? = nil
    ) async throws -> P.Output? where P.Output: Sendable {
        return try await self.outputs(confirmExpect, for: source, action).first
    }
    
    @available(iOS 16.0, *)
    public func failure<P: Publisher>(
        _ confirmExpect: ConfirmationExpectation,
        for source: P,
        _ action: (() -> Void)? = nil
    ) async throws -> P.Failure? {
        return try await confirmation { confirm in
            
            var error: P.Failure?
            
            source
                .sink { completion in
                    guard case let .failure(failure) = completion else { return }
                    error = failure
                    confirm()
                    
                } receiveValue: { _ in }
                .store(in: &self.cancelBag)
            
            action?()
            
            try await Task.sleep(for: confirmExpect.timeout)
            
            return error
        }
    }
}
