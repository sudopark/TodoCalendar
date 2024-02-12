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
    
    let keyChainStorage = FakeKeyChainStore()
    
    let commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        return service
    }()
    
    
    // TODO: test build 이면 empty remote 객체 제공
    let remoteAPI: any RemoteAPI = RemoteAPIImple()
}



// TODO: 임시로 가짜 키체인 스토어 운용

final class FakeKeyChainStore: KeyChainStorage, @unchecked Sendable {
    
    var storage: [String: (any Codable)] = [:]
    
    func setupSharedGroup(_ identifier: String) { }
    
    func load<T>(_ key: String) -> T? where T : Decodable {
        return self.storage[key] as? T
    }
    
    func update<T>(_ key: String, _ value: T) where T : Encodable {
        self.storage[key] = value as? any Codable
    }
    
    func remove(_ key: String) {
        self.storage[key] = nil
    }
}
