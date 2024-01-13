//
//  UserDefaultEnvironmentStorageImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 12/8/23.
//

import XCTest
import UnitTestHelpKit

@testable import Repository


class UserDefaultEnvironmentStorageImpleTests: BaseTestCase {
    
    var allKeys: [String] = [
        "BoolValue", "IntValue", "FloatValue", "DoubleValue", "StringValue", "CodableValue"
    ]
    
    struct DummyCodable: Codable, Equatable {
        let intValue: Int
    }
    
    private var store: UserDefaultEnvironmentStorageImple!
    
    override func setUpWithError() throws {
        self.store = .init()
    }
    
    override func tearDownWithError() throws {
        self.allKeys.forEach {
            self.store.remove($0)
        }
        self.store = nil
    }
}


extension UserDefaultEnvironmentStorageImpleTests {
    
    func testStorage_saveAndLoad() {
        // given
        func parameterizeTest<T: Codable & Equatable>(
            _ key: String,
            _ value: T,
            expectInitial: T?
        ) {
            // given
            let initialValue: T? = self.store.load(key)
            
            // when
            self.store.update(key, value)
            
            // then
            let afterSaveValue: T? = self.store.load(key)
            XCTAssertEqual(initialValue, expectInitial)
            XCTAssertEqual(afterSaveValue, value)
        }
        // when + then
        parameterizeTest("BoolValue", true, expectInitial: false)
        parameterizeTest("IntValue", Int(100), expectInitial: 0)
        parameterizeTest("FloatValue", Float(200), expectInitial: 0)
        parameterizeTest("DoubleValue", Double(230), expectInitial: 0)
        parameterizeTest("StringValue", "some", expectInitial: nil)
        parameterizeTest("CodableValue", DummyCodable(intValue: 12), expectInitial: nil)
    }
}
