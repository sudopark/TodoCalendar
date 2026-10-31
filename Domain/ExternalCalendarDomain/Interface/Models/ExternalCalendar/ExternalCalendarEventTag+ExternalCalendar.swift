//
//  ExternalCalendarEventTag+ExternalCalendar.swift
//  ExternalCalendarDomainInterface
//
//  Created by sudo.park on 10/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import EventDomainInterface


extension ExternalCalendarEventTag {

    public init(_ tag: GoogleCalendar.Tag) {
        self.init(tagId: tag.tagId, name: tag.name, colorHex: tag.colorHex, ownerId: tag.ownerId)
        self.foregroundColorHex = tag.foregroundColorHex
        self.colorId = tag.colorId
    }

    public init(_ tag: AppleCalendar.Tag) {
        self.init(tagId: tag.tagId, name: tag.name, colorHex: tag.colorHex)
    }
}
