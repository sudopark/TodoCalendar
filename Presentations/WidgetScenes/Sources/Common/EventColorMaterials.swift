//
//  EventColorMaterials.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Domain


public protocol EventColorMaterials {
    
    var defaultTagColorSetting: DefaultEventTagColorSetting { get }
    var customTagMap: [String: any EventTag] { get }
    var googleCalendarColors: GoogleCalendar.Colors { get }
    var googleCalendarTags: [String: GoogleCalendar.Tag] { get }
    var appleCalendarTags: [String: AppleCalendar.Tag] { get }
}

extension EventColorMaterials {
    
    public var colorPalette: EventColorPalette {
        return EventColorPalette(
            defaultSetting: self.defaultTagColorSetting,
            customTagMap: self.customTagMap,
            googleColors: self.googleCalendarColors,
            googleTags: self.googleCalendarTags,
            appleTags: self.appleCalendarTags
        )
    }
}
