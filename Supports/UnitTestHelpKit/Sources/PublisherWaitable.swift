//
//  PublisherWaitable.swift
//  UnitTestHelpKit
//
//  Created by sudo.park on 2023/03/25.
//

import XCTest
import Foundation
import Combine


public protocol PublisherWaitable: AnyObject {
    
    var cancelBag: Set<AnyCancellable>! { get set }
}


extension PublisherWaitable where Self: XCTestCase {
    
    public func waitOutputs<P: Publisher>(
        _ expect: XCTestExpectation,
        for source: P,
        timeout: TimeInterval = 0.5,
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
        timeout: TimeInterval = 0.5,
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
        timeout: TimeInterval = 0.5,
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

// 방출값을 스레드 안전하게 모으는 박스. early-exit 폴링 시 sink 스레드의 append와
// 폴링 루프의 read가 동시에 일어나므로 lock으로 보호한다.
private final class WaitableOutputStore<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [T] = []
    func append(_ item: T) { self.lock.lock(); self.items.append(item); self.lock.unlock() }
    var count: Int { self.lock.lock(); defer { self.lock.unlock() }; return self.items.count }
    func snapshot() -> [T] { self.lock.lock(); defer { self.lock.unlock() }; return self.items }
}

extension PublisherWaitable {
    
    @available(iOS 16.0, *)
    public func expectConfirm(
        _ description: String
    ) -> ConfirmationExpectation {
        return .init(comment: .init(stringLiteral: description), count: 1, timeout: .seconds(1))
    }

    @available(iOS 16.0, *)
    public func outputs<P: Publisher>(
        _ confirmExpect: ConfirmationExpectation,
        for source: P,
        _ action: (() async throws -> Void)? = nil
    ) async throws -> [P.Output] where P.Output: Sendable {
        return try await confirmation(confirmExpect.comment, expectedCount: confirmExpect.count) { confirm in

            let store = WaitableOutputStore<P.Output>()
            let cancellable = source
                .sink { _ in } receiveValue: { output in
                    store.append(output)
                    confirm()
                }
            cancellable.store(in: &self.cancelBag)

            try await action?()

            // count 충족 시 즉시 종료, 아니면 timeout까지만 대기 (early-exit).
            // count == 0("방출 없음" 단언)은 끝까지 기다려야 잘못된 방출을 잡아낸다.
            let deadline = ContinuousClock.now + confirmExpect.timeout
            while confirmExpect.count == 0 || store.count < confirmExpect.count,
                  ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(5))
            }
            cancellable.cancel()
            return store.snapshot()
        }
    }
 
    @available(iOS 16.0, *)
    public func firstOutput<P: Publisher>(
        _ confirmExpect: ConfirmationExpectation,
        for source: P,
        _ action: (() async throws -> Void)? = nil
    ) async throws -> P.Output? where P.Output: Sendable {
        return try await self.outputs(confirmExpect, for: source, action).first
    }
    
    @available(iOS 16.0, *)
    public func failure<P: Publisher>(
        _ confirmExpect: ConfirmationExpectation,
        for source: P,
        _ action: (() async throws -> Void)? = nil
    ) async throws -> P.Failure? {
        return try await confirmation { confirm in

            let store = WaitableOutputStore<P.Failure>()
            let cancellable = source
                .sink { completion in
                    guard case let .failure(failure) = completion else { return }
                    store.append(failure)
                    confirm()
                } receiveValue: { _ in }
            cancellable.store(in: &self.cancelBag)

            try await action?()

            let deadline = ContinuousClock.now + confirmExpect.timeout
            while store.count < 1, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(5))
            }
            cancellable.cancel()
            return store.snapshot().first
        }
    }
}
