//
//  InfoPlist_Secrets.swift
//  TodoCalendarAppManifests
//
//  Created by sudo.park on 2023/12/16.
//

import ProjectDescription


extension Project {
    
    static let googleClientId: String = "dummy.id"
    static let googleReverseAppId: String = "id.dummy"
    
    // debug signing
    public static let debugAppSigningSetting: SettingsDictionary = [:]
    
    public static let debugWidgetSigningSetting: SettingsDictionary = [:]
    
    public static let debugAppIntentSigningSetting: SettingsDictionary = [:]
    
    // release signing
    public static let releaseAppSigningSetting: SettingsDictionary = [:]
    
    public static let releaseWidgetSigningSetting: SettingsDictionary = [:]
    
    public static let releaseAppIntentSigningSetting: SettingsDictionary = [:]
}
