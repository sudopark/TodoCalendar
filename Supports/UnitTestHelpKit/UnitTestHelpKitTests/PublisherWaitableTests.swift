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
