//
//  GoogleCalendar+Mapping.swift
//  Repository
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


struct GoogleCalendarColorsMapper {
    
    private enum CodingKeys: String, CodingKey {
        case calendar
        case background
        case foreground
        case event
    }
    
    let colors: GoogleCalendarColors
    
    init(decode data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw RuntimeError("invalid form of json")
        }
        let calendarJson = json[CodingKeys.calendar.rawValue] as? [String: Any] ?? [:]
        let eventJson = json[CodingKeys.event.rawValue] as? [String: Any] ?? [:]
        
        let decodeColorSet: (Any) -> GoogleCalendarColors.ColorSet? = { any in
            guard let subDict = any as? [String: Any],
                  let background = subDict[CodingKeys.background.rawValue] as? String,
                  let foreground = subDict[CodingKeys.foreground.rawValue] as? String
            else { return nil }
            return .init(foregroundHex: foreground, backgroudHex: background)
        }
        
        self.colors = .init(
            calendars: calendarJson.compactMapValues(decodeColorSet),
            events: eventJson.compactMapValues(decodeColorSet)
        )
    }
}
