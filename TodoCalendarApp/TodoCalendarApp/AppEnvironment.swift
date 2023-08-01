//
//  AppEnvironment.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/02.
//

import Foundation


struct AppEnvironment {
    
    static var isTestBuild: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #endif
        return false
    }
}
