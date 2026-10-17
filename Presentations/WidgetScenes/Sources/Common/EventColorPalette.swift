//
//  EventColorPalette.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import CommonPresentation


public struct EventColorPalette: Sendable {
    
    private let defaultSetting: DefaultEventTagColorSetting
    private let customTagMap: [String: any EventTag]
    private let googleColors: GoogleCalendar.Colors
    private let googleTags: [String: GoogleCalendar.Tag]
    private let appleTags: [String: AppleCalendar.Tag]
    
    public init(
        defaultSetting: DefaultEventTagColorSetting,
        customTagMap: [String: any EventTag],
        googleColors: GoogleCalendar.Colors,
        googleTags: [String: GoogleCalendar.Tag],
        appleTags: [String: AppleCalendar.Tag]
    ) {
        self.defaultSetting = defaultSetting
        self.customTagMap = customTagMap
        self.googleColors = googleColors
        self.googleTags = googleTags
        self.appleTags = appleTags
    }
    
    public func color(for source: any EventTagColorSource) -> UIColor {
        let defaultColors = EventTagColorSet(self.defaultSetting)
        
        if let google = source as? GoogleCalendarEventColorSource {
            let appearance = ViewAppearance(google: self.googleColors, self.googleTags)
            return appearance.googleEventColor(google.colorId, google.calendarId)
        }
        if let apple = source as? AppleCalendarEventColorSource {
            return self.appleTags[apple.calendarId]?.colorHex
                .flatMap { UIColor.from(hex: $0) } ?? defaultColors.defaultColor
        }
        switch source as? EventTagId {
        case .holiday:
            return defaultColors.holiday
            
        case .default:
            return defaultColors.defaultColor
            
        case .custom(let id):
            return self.customTagMap[id]?.colorHex
                .flatMap { UIColor.from(hex: $0) } ?? defaultColors.defaultColor
            
        default:
            return defaultColors.defaultColor
        }
    }
}
