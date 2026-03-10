//
//  ExternalCalendarDBConnectionPool.swift
//  Repository
//
//  Created by sudo.park on 3/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SQLiteService
import Extensions


public protocol ExternalCalendarSQLiteConnectionPool: ExternalCalendarDBConnectionPool {

    func connection(serviceId: String) async throws -> SQLiteService
}


public actor ExternalCalendarSQLiteConnectionPoolImple: ExternalCalendarSQLiteConnectionPool {
    
    private final class DBConnection {
        var connectionCount: Int
        let sqliteService: SQLiteService
        init(connectionCount: Int = 1, sqliteService: SQLiteService) {
            self.connectionCount = connectionCount
            self.sqliteService = sqliteService
        }
    }
    
    private let dbPathMap: [String: String]
    private var connectionPool: [String: DBConnection] = [:]
    public init(dbPathMap: [String : String]) {
        self.dbPathMap = dbPathMap
    }
}

extension ExternalCalendarSQLiteConnectionPoolImple {
    
    private var errorKey: String { "externalCalendarDBConnectionFail" }
    
    public func open(serviceId: String) async throws {
        if let connection = self.connectionPool[serviceId] {
            connection.connectionCount += 1
            return
        }
        
        guard let path = self.dbPathMap[serviceId]
        else {
            throw RuntimeError(
                key: self.errorKey,
                "not support service: \(serviceId)"
            )
        }
        
        let service = SQLiteService()
        try await service.async.open(path: path)
        let newConnection = DBConnection(sqliteService: service)
        self.connectionPool[serviceId] = newConnection
    }
    
    public func close(serviceId: String) async throws {
        guard let connection = self.connectionPool[serviceId]
        else { return }
        
        connection.connectionCount -= 1
        guard connection.connectionCount <= 0 else { return }
        try await connection.sqliteService.async.close()
        self.connectionPool.removeValue(forKey: serviceId)
    }
    
    public func connection(serviceId: String) async throws -> SQLiteService {
        guard let connection = self.connectionPool[serviceId]
        else {
            throw RuntimeError(key: self.errorKey, "db connection not prepared: \(serviceId)")
        }
        return connection.sqliteService
    }
}
