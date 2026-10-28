//
//  ExternalCalendarEventTag+ExternalCalendar.swift
//  Domain
//
//  Created by sudo.park on 10/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation


extension ExternalCalendarEventTag {

    public init(_ tag: GoogleCalendar.Tag) {
        self.tagId = tag.tagId
        self.name = tag.name
        self.colorHex = tag.colorHex
        self.foregroundColorHex = tag.foregroundColorHex
        self.colorId = tag.colorId
        self.ownerId = tag.ownerId
    }

    public init(_ tag: AppleCalendar.Tag) {
        self.tagId = tag.tagId
        self.name = tag.name
        self.colorHex = tag.colorHex
    }
}
