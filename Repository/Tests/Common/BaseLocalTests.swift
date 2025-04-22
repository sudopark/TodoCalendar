//
//  BaseLocalTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2023/05/21.
//

import XCTest
import SQLiteService
import UnitTestHelpKit

@testable import Repository


class BaseLocalTests: BaseTestCase {
    
    var fileName: String = "test"
    
    func testDBPath() -> String {
        return try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(self.fileName).db")
            .path
    }
    
    var sqliteService: SQLiteService!
    
    override func setUpWithError() throws {
        self.timeout = 1.0
        let path = self.testDBPath()
        print("will open => \(path)")
        self.sqliteService = SQLiteService()
        _ = self.sqliteService.open(path: path)
    }
    
    override func tearDownWithError() throws {
        self.sqliteService = nil
        try? FileManager.default.removeItem(atPath: self.testDBPath())
    }
}


protocol LocalTestable {
    
    var sqliteService: SQLiteService { get }
}

extension LocalTestable {
    
    private func testDBPath(name: String) -> String {
        return try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(name).db")
            .path
    }
    
    private func open(db fileName: String) throws{
        let path = self.testDBPath(name: fileName)
        print(path)
        _ = self.sqliteService.open(path: path)
    }
    
    private func closeAndRemove(db fileName: String) throws {
        let path = self.testDBPath(name: fileName)
        self.sqliteService.close()
        try FileManager.default.removeItem(atPath: path)
    }
    
    func runTestWithOpenClose(_ fileName: String, _ testing: @escaping() async throws -> Void) async throws {
        try? self.open(db: fileName)
        defer {
            try? self.closeAndRemove(db: fileName)
        }
        try await testing()
    }
}
