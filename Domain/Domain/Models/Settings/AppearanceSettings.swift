//
//  AppearanceSettings.swift
//  Domain
//
//  Created by sudo.park on 2023/08/07.
//

import Foundation


public enum ColorSetKeys: String, Sendable {
    case defaultLight
}

public enum FontSetKeys: String, Sendable {
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

// MARK: - edit params

public struct EditAppearanceSettingParams {
    
    public struct EditEventTagColorParams {
        public var newHolidayTagColor: String?
        public var newDefaultTagColor: String?
        public init() { }
    }
    
    public var newTagColorSetting: EditEventTagColorParams?
    public var newColorSetKey: ColorSetKeys?
    public var newFontSetKcy: FontSetKeys?
    
    public init() { }
    
    public var isValid: Bool {
        return self.newTagColorSetting?.newHolidayTagColor != nil
            || self.newTagColorSetting?.newDefaultTagColor != nil
            || self.newColorSetKey != nil
            || self.newFontSetKcy != nil
    }
}
