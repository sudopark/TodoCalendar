//
//  GoogleCalendarEventColorResolverTests.swift
//  DomainTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Prelude
import Optics

@testable import Domain


@Suite("GoogleCalendarEventColorResolverTests")
struct GoogleCalendarEventColorResolverTests {

    private func makeTag(
        id: String, ownerId: String = "", backgroundColorHex: String? = nil, colorId: String? = nil
    ) -> GoogleCalendar.Tag {
        return GoogleCalendar.Tag(id: id, name: id)
            |> \.ownerId .~ ownerId
            |> \.backgroundColorHex .~ backgroundColorHex
            |> \.colorId .~ colorId
    }

    private func makePalette(
        ownerId: String,
        calendars: [String: String] = [:],
        events: [String: String] = [:]
    ) -> GoogleCalendar.Colors {
        return GoogleCalendar.Colors(
            ownerId: ownerId,
            calendars: calendars.mapValues { .init(foregroundHex: "fg", backgroudHex: $0) },
            events: events.mapValues { .init(foregroundHex: "fg", backgroudHex: $0) }
        )
    }
}


// MARK: - 이벤트 색 우선

extension GoogleCalendarEventColorResolverTests {

    @Test func colorHex_whenEventColorIdMatchesAccountPalette_prefersItOverCalendarColor() {
        // given — 캘린더 자체 색과 이벤트 개별 색이 둘 다 있는 상황
        let tag = self.makeTag(id: "cal1", ownerId: "acc1", backgroundColorHex: "#calendarColor")
        let palette = self.makePalette(ownerId: "acc1", events: ["ev1": "#eventColor"])
        let resolver = GoogleCalendar.EventColorResolver(
            calendarTags: ["cal1": tag], palettes: ["acc1": palette]
        )

        // when
        let hex = resolver.colorHex(eventColorId: "ev1", calendarId: "cal1")

        // then
        #expect(hex == "#eventColor")
    }

    @Test func colorHex_multiAccount_usesOwningAccountsPaletteForSameColorId() {
        // given — 두 계정이 같은 colorId 키를 다른 색으로 갖는다
        let tag = self.makeTag(id: "cal1", ownerId: "acc2")
        let resolver = GoogleCalendar.EventColorResolver(
            calendarTags: ["cal1": tag],
            palettes: [
                "acc1": self.makePalette(ownerId: "acc1", events: ["5": "#acc1Color"]),
                "acc2": self.makePalette(ownerId: "acc2", events: ["5": "#acc2Color"])
            ]
        )

        // when
        let hex = resolver.colorHex(eventColorId: "5", calendarId: "cal1")

        // then
        #expect(hex == "#acc2Color")
    }
}


// MARK: - 캘린더 색 폴백 (이벤트 개별 색 없음)

extension GoogleCalendarEventColorResolverTests {

    @Test func colorHex_whenNoEventColorId_fallsBackToCalendarTagBackgroundColor() {
        // given
        let tag = self.makeTag(id: "cal1", ownerId: "acc1", backgroundColorHex: "#calendarColor")
        let resolver = GoogleCalendar.EventColorResolver(
            calendarTags: ["cal1": tag], palettes: [:]
        )

        // when
        let hex = resolver.colorHex(eventColorId: nil, calendarId: "cal1")

        // then
        #expect(hex == "#calendarColor")
    }

    @Test func colorHex_whenTagHasNoBackgroundColor_fallsBackToPaletteCalendarColor() {
        // given — 캘린더 자체 색은 없고 팔레트 colorId만 있는 상황 (2차 증상 케이스)
        let tag = self.makeTag(id: "cal1", ownerId: "acc1", colorId: "pal1")
        let palette = self.makePalette(ownerId: "acc1", calendars: ["pal1": "#paletteCalendarColor"])
        let resolver = GoogleCalendar.EventColorResolver(
            calendarTags: ["cal1": tag], palettes: ["acc1": palette]
        )

        // when
        let hex = resolver.colorHex(eventColorId: nil, calendarId: "cal1")

        // then
        #expect(hex == "#paletteCalendarColor")
    }
}


// MARK: - accountId 미상 폴백 (calendarId가 태그 맵에 없음)

extension GoogleCalendarEventColorResolverTests {

    @Test func colorHex_whenCalendarNotInTagMap_searchesAllPalettesByEventColorId() {
        // given — 태그 로딩 전 등 accountId를 못 구하면 전 팔레트를 훑는다
        let palette = self.makePalette(ownerId: "acc-unknown", events: ["ev1": "#anyAccountColor"])
        let resolver = GoogleCalendar.EventColorResolver(
            calendarTags: [:], palettes: ["acc-unknown": palette]
        )

        // when
        let hex = resolver.colorHex(eventColorId: "ev1", calendarId: "missing-cal")

        // then
        #expect(hex == "#anyAccountColor")
    }

    @Test func colorHex_whenCalendarNotInTagMap_andNoEventColorId_returnsNil() {
        // given — 태그가 없어 팔레트 colorId(paletteId) 자체를 못 구하므로 폴백 대상이 없다
        let palette = self.makePalette(ownerId: "acc-unknown", calendars: ["pal1": "#anyAccountColor"])
        let resolver = GoogleCalendar.EventColorResolver(
            calendarTags: [:], palettes: ["acc-unknown": palette]
        )

        // when
        let hex = resolver.colorHex(eventColorId: nil, calendarId: "missing-cal")

        // then
        #expect(hex == nil)
    }
}


// MARK: - 전부 없을 때 nil

extension GoogleCalendarEventColorResolverTests {

    @Test func colorHex_whenNothingMatchesAnywhere_returnsNil() {
        // given
        let resolver = GoogleCalendar.EventColorResolver(calendarTags: [:], palettes: [:])

        // when
        let hex = resolver.colorHex(eventColorId: "ev1", calendarId: "cal1")

        // then
        #expect(hex == nil)
    }
}
