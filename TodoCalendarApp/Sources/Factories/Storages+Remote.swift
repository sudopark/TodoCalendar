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
    
    let keyChainStorage = KeyChainStorageImple(identifier: AppEnvironment.keyChainStoreName)
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        return service
    }()
    
    
    // TODO: test build 이면 empty remote 객체 제공
    lazy var remoteAPI: any RemoteAPI = {
        let environment = RemoteEnvironment(calendarAPIHost: "some")
        return RemoteAPIImple(environment: environment)
    }()
}
