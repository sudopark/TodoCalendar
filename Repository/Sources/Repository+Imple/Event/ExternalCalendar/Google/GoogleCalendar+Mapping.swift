//
//  GoogleCalendar+Mapping.swift
//  Repository
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


// MARK: - GoogleCalendarColorsMapper

struct GoogleCalendarColorsMapper {
    
    private enum CodingKeys: String, CodingKey {
        case calendar
        case background
        case foreground
        case event
    }
    
    let colors: GoogleCalendar.Colors
    
    init(decode data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw RuntimeError("invalid form of json")
        }
        let calendarJson = json[CodingKeys.calendar.rawValue] as? [String: Any] ?? [:]
        let eventJson = json[CodingKeys.event.rawValue] as? [String: Any] ?? [:]
        
        let decodeColorSet: (Any) -> GoogleCalendar.Colors.ColorSet? = { any in
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


// MARK: - GoogleCalendarEventTagMapper

struct GoogleCalendarEventTagMapper: Decodable {
    
    let calendar: GoogleCalendar.Tag
    
    private enum CodingKeys: String, CodingKey {
        case id
        case summary
        case description
        case backgroundColor
        case foregroundColor
        case colorId
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.calendar = GoogleCalendar.Tag(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .summary)
        )
        |> \.description .~ (try? container.decode(String.self, forKey: .description))
        |> \.backgroundColorHex .~ (try? container.decode(String.self, forKey: .backgroundColor))
        |> \.foregroundColorHex .~ (try? container.decode(String.self, forKey: .foregroundColor))
        |> \.colorId .~ (try? container.decode(String.self, forKey: .colorId))
    }
}


struct GoogleCalendarEventTagListMapper: Decodable {
    
    let calendars: [GoogleCalendar.Tag]
    
    private enum CodingKeys: String, CodingKey {
        case items
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mappers = try container.decode([GoogleCalendarEventTagMapper].self, forKey: .items)
        self.calendars = mappers.map { $0.calendar }
    }
}
