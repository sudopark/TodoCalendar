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

    // Google이 공개한 테스트 앱 ID — 실계정 없이도 빌드·구동된다
    static let admobAppId: String = "ca-app-pub-3940256099942544~1458002511"

    // debug signing
    public static let debugAppSigningSetting: SettingsDictionary = [:]
    
    public static let debugWidgetSigningSetting: SettingsDictionary = [:]
    
    public static let debugAppIntentSigningSetting: SettingsDictionary = [:]

    public static let debugShareSigningSetting: SettingsDictionary = [:]

    // release signing
    public static let releaseAppSigningSetting: SettingsDictionary = [:]
    
    public static let releaseWidgetSigningSetting: SettingsDictionary = [:]
    
    public static let releaseAppIntentSigningSetting: SettingsDictionary = [:]

    public static let releaseShareSigningSetting: SettingsDictionary = [:]
}
