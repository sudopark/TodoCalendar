//
//  Singleton.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain
import Repository
import SQLiteService


final class Singleton {
    
    private init() { }
    
    static let shared = Singleton()
    
    let sharedDataStore: SharedDataStore = .init()
    
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple()
    
    let commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        return service
    }()
    
    
    let remoteAPI: RemoteAPI = RemoteAPIImple()
}

