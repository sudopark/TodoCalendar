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


public struct AppearanceSettings {
    
    public let colorSetKey: ColorSetKeys
    public let fontSetKey: FontSetKeys
    
    public init(colorSetKey: ColorSetKeys, fontSetKey: FontSetKeys) {
        self.colorSetKey = colorSetKey
        self.fontSetKey = fontSetKey
    }
}
