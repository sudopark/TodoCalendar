//
//  AppEnvironment.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/02.
//

import Foundation


struct AppEnvironment {
    
    static var useEmulator: Bool { false }
    
    static var isTestBuild: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #endif
        return false
    }
    
    private static var dbFileName: String {
        if self.isTestBuild {
            return "test_dummy"
        } else {
            return "models"
        }
    }
    
    static var groupID: String {
        return "group.sudo.park.todo-calendar"
    }
    
    static func dbFilePath(for userId: String?) -> String {
        let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID)
        let fileName = userId.map { "\(self.dbFileName)_\($0)" } ?? self.dbFileName
        let dbUrl = directory?.appending(path: "\(fileName).db")
        return dbUrl?.path() ?? ""
    }
    
    static var keyChainStoreName: String { "TodoCalendar" }
}
