//
//  EventColorPaletteTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit
import Domain
import CommonPresentation

@testable import WidgetScenes


struct EventColorPaletteTests {
    
    private var defaultSetting: DefaultEventTagColorSetting {
        return .init(holiday: "#D6236A", default: "#088CDA")
    }
    
    private var googleTag: GoogleCalendar.Tag {
        var tag = GoogleCalendar.Tag(id: "google-cal", name: "google calendar")
        tag.ownerId = "google-owner"
        tag.backgroundColorHex = "#111111"
        return tag
    }
    
    private var googleColors: GoogleCalendar.Colors {
        return .init(
            ownerId: "google-owner",
            calendars: ["google-cal": .init(foregroundHex: "#000000", backgroudHex: "#222222")],
            events: ["event-color": .init(foregroundHex: "#000000", backgroudHex: "#445566")]
        )
    }
    
    private func makePalette(
        appleColorHex: String? = "#AABBCC",
        customTagColorHex: String? = "#123456"
    ) -> EventColorPalette {
        let customTagMap: [String: any EventTag] = customTagColorHex.map {
            ["custom-tag": CustomEventTag(uuid: "custom-tag", name: "custom", colorHex: $0)]
        } ?? [:]
        return EventColorPalette(
            defaultSetting: self.defaultSetting,
            customTagMap: customTagMap,
            googleColors: self.googleColors,
            googleTags: ["google-cal": self.googleTag],
            appleTags: [
                "apple-cal": .init(id: "apple-cal", name: "apple calendar", colorHex: appleColorHex)
            ]
        )
    }
}

// MARK: - 외부 캘린더 소스

extension EventColorPaletteTests {
    
    @Test func palette_whenSourceIsGoogle_resolvesEventColorFromPalette() {
        // given
        let palette = self.makePalette()
        let source = GoogleCalendarEventColorSource(calendarId: "google-cal", colorId: "event-color")
        
        // when
        let color = palette.color(for: source)
        
        // then
        #expect(color == UIColor.from(hex: "#445566"))
    }
    
    @Test func palette_whenSourceIsApple_resolvesByCalendarTagHex() {
        // given
        let palette = self.makePalette()
        let source = AppleCalendarEventColorSource(calendarId: "apple-cal")
        
        // when
        let color = palette.color(for: source)
        
        // then
        #expect(color == UIColor.from(hex: "#AABBCC"))
    }
    
    @Test func palette_whenSourceIsAppleAndHexUnparsable_fallbackToDefault() {
        // given
        let palette = self.makePalette(appleColorHex: "#nothex")
        let source = AppleCalendarEventColorSource(calendarId: "apple-cal")
        
        // when
        let color = palette.color(for: source)
        
        // then
        #expect(color == UIColor.from(hex: "#088CDA"))
    }
}

// MARK: - 앱 태그 소스

extension EventColorPaletteTests {
    
    @Test func palette_whenSourceIsHolidayTag_resolvesHolidayColor() {
        // given
        let palette = self.makePalette()
        
        // when
        let color = palette.color(for: EventTagId.holiday)
        
        // then
        #expect(color == UIColor.from(hex: "#D6236A"))
    }
    
    @Test func palette_whenSourceIsDefaultTag_resolvesDefaultColor() {
        // given
        let palette = self.makePalette()
        
        // when
        let color = palette.color(for: EventTagId.default)
        
        // then
        #expect(color == UIColor.from(hex: "#088CDA"))
    }
    
    @Test func palette_whenSourceIsCustomTag_resolvesCustomHex() {
        // given
        let palette = self.makePalette()
        
        // when
        let color = palette.color(for: EventTagId.custom("custom-tag"))
        
        // then
        #expect(color == UIColor.from(hex: "#123456"))
    }
    
    @Test func palette_whenCustomTagNotFound_fallbackToDefault() {
        // given
        let palette = self.makePalette(customTagColorHex: nil)
        
        // when
        let color = palette.color(for: EventTagId.custom("custom-tag"))
        
        // then
        #expect(color == UIColor.from(hex: "#088CDA"))
    }
}

// MARK: - 알 수 없는 소스

extension EventColorPaletteTests {
    
    private struct UnknownColorSource: EventTagColorSource { }
    
    @Test func palette_whenSourceIsUnknownType_fallbackToDefault() {
        // given
        let palette = self.makePalette()
        
        // when
        let color = palette.color(for: UnknownColorSource())
        
        // then
        #expect(color == UIColor.from(hex: "#088CDA"))
    }
}

// MARK: - EventColorMaterials 조립

extension EventColorPaletteTests {
    
    @Test func colorMaterials_assemblePaletteFromItsOwnFields() {
        // given
        let model = EventListWidgetViewModel(
            pages: [],
            defaultTagColorSetting: self.defaultSetting,
            customTagMap: [
                "custom-tag": CustomEventTag(uuid: "custom-tag", name: "c", colorHex: "#123456")
            ],
            googleCalendarColors: self.googleColors,
            googleCalendarTags: ["google-cal": self.googleTag],
            appleCalendarTags: [
                "apple-cal": .init(id: "apple-cal", name: "apple", colorHex: "#AABBCC")
            ]
        )
        
        // when
        let palette = model.colorPalette
        
        // then
        #expect(palette.color(for: EventTagId.custom("custom-tag")) == UIColor.from(hex: "#123456"))
        #expect(palette.color(for: EventTagId.holiday) == UIColor.from(hex: "#D6236A"))
        #expect(
            palette.color(for: AppleCalendarEventColorSource(calendarId: "apple-cal"))
            == UIColor.from(hex: "#AABBCC")
        )
        #expect(
            palette.color(
                for: GoogleCalendarEventColorSource(calendarId: "google-cal", colorId: "event-color")
            ) == UIColor.from(hex: "#445566")
        )
    }
}
