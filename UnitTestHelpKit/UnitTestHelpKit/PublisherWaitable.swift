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
