//
//  PublisherWaitableTests.swift
//  UnitTestHelpKitTests
//
//  Created by sudo.park on 2023/03/25.
//

import XCTest
import Combine
import UnitTestHelpKit


class PublisherWaitableTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var subject: PassthroughSubject<Int, Error>!
    
    override func setUpWithError() throws {
        self.cancelBag = []
        self.subject = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.subject = nil
    }
}


extension PublisherWaitableTests {
    
    func test_waitOutputs() {
        // given
        let expect = expectation(description: "wait outputs")
        expect.expectedFulfillmentCount = 10
        
        // when
        let outputs = self.waitOutputs(expect, for: self.subject) {
            (0..<10).forEach {
                self.subject.send($0)
            }
        }
        
        // then
        XCTAssertEqual(outputs, Array(0..<10))
    }
    
    func test_waitFirstOutput() {
        // given
        let expect = expectation(description: "wait first output")
        
        // when
        let output = self.waitFirstOutput(expect, for: self.subject.dropFirst(3)) {
            (0..<4).forEach {
                self.subject.send($0)
            }
        }
        
        // then
        XCTAssertEqual(output, 3)
    }
    
    func test_waitError() {
        // given
        let expect = expectation(description: "wait error")
        struct DummyError: Error { }
        
        // when
        let error = self.waitError(expect, for: self.subject) {
            self.subject.send(completion: .failure(DummyError()))
        }
        
        // then
        XCTAssertEqual(error is DummyError, true)
    }
}


// MARK: - with Testing library

import Testing

final class PublisherWaitableSwiftTesting: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    let subject = PassthroughSubject<Int, any Error>()
}

extension PublisherWaitableSwiftTesting {
    
    @available(iOS 16.0, *)
    @Test func wait_outputs() async throws {
        // given
        let expect = expectConfirm("wait outputs")
        expect.count = 10
        
        // when
        let outputs = try await self.outputs(expect, for: self.subject) {
            (0..<10).forEach { self.subject.send($0) }
        }
        
        // then
        #expect(outputs == Array(0..<10))
    }
    
    @available(iOS 16.0, *)
    @Test func wait_firstOutput() async throws {
        // given
        let expect = expectConfirm("wait first output")
        
        // when
        let output = try await self.firstOutput(expect, for: self.subject.dropFirst(3)) {
            (0..<4).forEach { self.subject.send($0) }
        }
        
        // then
        #expect(output == 3)
    }
    
    @available(iOS 16.0, *)
    @Test func async_outputs() async throws {
        // given
        let expect = expectConfirm("wait async outputs")
        expect.count = 10
        expect.timeout = .seconds(1)
        
        // when
        let outputs = try await self.outputs(expect, for: self.subject) {
            (0..<10).forEach { int in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                    self.subject.send(int)
                }
            }
        }
        
        // then
        #expect(outputs == Array(0..<10))
    }
    
    @available(iOS 16.0, *)
    @Test func wait_error() async throws {
        // given
        let expect = expectConfirm("wait error")
        struct DummyError: Error { }
        
        // when
        let error = try await self.failure(expect, for: self.subject) {
            self.subject.send(completion: .failure(DummyError()))
        }
        
        // then
        #expect(error != nil)
        #expect(error is DummyError)
    }
}
