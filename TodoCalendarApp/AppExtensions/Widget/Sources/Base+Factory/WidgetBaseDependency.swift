//
//  WidgetBaseDependency.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 6/8/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository
import SQLiteService
import Alamofire


// MARK: - WidgetBaseDependency

final class WidgetBaseDependency {
    
    init() { }
    
    let userDefaultEnvironmentStorage = UserDefaultEnvironmentStorageImple(
        suiteName: AppEnvironment.groupID
    )
    
    let keyChainStorage: KeyChainStorageImple = {
        let store = KeyChainStorageImple(identifier: AppEnvironment.keyChainStoreName)
        store.setupSharedGroup(AppEnvironment.groupID)
        return store
    }()
    
    lazy var commonSqliteService: SQLiteService = {
        let service = SQLiteService()
        let userId = self.keyChainStorage.loadCurrentAuth()?.uid
        let path = AppEnvironment.dbFilePath(for: userId)
        _ = service.open(path: path)
        return service
    }()
    
    lazy var remoteAPI: RemoteAPIImple = {
        fatalError()
    }()
}
