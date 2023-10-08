//
//  AppearanceSettings.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation


public enum ColorSetKeys: String {
    case defaultLight
}

public enum FontSetKeys: String {
    case systemDefault
}

public struct EventTagColorSetting {
    public let holiday: String
    public let `default`: String
    
    public init(holiday: String, `default`: String) {
        self.holiday = holiday
        self.default = `default`
    }
}

public struct AppearanceSettings {
    
    public let tagColorSetting: EventTagColorSetting
    public let colorSetKey: ColorSetKeys
    public let fontSetKey: FontSetKeys
    
    public init(
        tagColorSetting: EventTagColorSetting,
        colorSetKey: ColorSetKeys,
        fontSetKey: FontSetKeys
    ) {
        self.tagColorSetting = tagColorSetting
        self.colorSetKey = colorSetKey
        self.fontSetKey = fontSetKey
    }
}
