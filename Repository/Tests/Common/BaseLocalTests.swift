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
    private var dbFileName: String = "test"
    
    func testDBPath() -> String {
        return try! FileManager.default
            .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("\(self.dbFileName).db")
            .path
    }
    
    var sqliteService: SQLiteService!
    
    override func setUpWithError() throws {
        self.timeout = 1.0
        // 앞 테스트의 커넥션이 아직 살아 있어도 같은 vnode 를 물지 않도록 테스트마다 다른 파일을 연다
        self.dbFileName = "\(self.fileName)_\(UUID().uuidString)"
        let path = self.testDBPath()
        print("will open => \(path)")
        self.sqliteService = SQLiteService()
        _ = self.sqliteService.open(path: path)
    }
    
    override func tearDown() async throws {
        let path = self.testDBPath()
        try? await self.sqliteService?.async.close()
        self.sqliteService = nil
        try? FileManager.default.removeItem(atPath: path)
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
    
    private func open(db fileName: String) async throws {
        let path = self.testDBPath(name: fileName)
        print(path)
        try await self.sqliteService.async.open(path: path)
    }
    
    private func closeAndRemove(db fileName: String) async throws {
        let path = self.testDBPath(name: fileName)
        try await self.sqliteService.async.close()
        try FileManager.default.removeItem(atPath: path)
    }
    
    func runTestWithOpenClose(_ fileName: String, _ testing: @escaping() async throws -> Void) async throws {
        try? await self.open(db: fileName)
        
        do {
            try await testing()
            try? await self.closeAndRemove(db: fileName)
        } catch {
            try? await self.closeAndRemove(db: fileName)
            throw error
        }
    }
}
