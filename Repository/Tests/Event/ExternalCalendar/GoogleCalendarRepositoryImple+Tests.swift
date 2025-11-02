//
//  GoogleCalendarRepositoryImple+Tests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import SQLiteService
import UnitTestHelpKit

@testable import Repository


@Suite("GoogleCalendarRepositoryImple_Tests", .serialized)
final class GoogleCalendarRepositoryImple_Tests: PublisherWaitable, LocalTestable {
    
    var cancelBag: Set<AnyCancellable>! = []
    let sqliteService: SQLiteService = .init()
    let cacheStorage: GoogleCalendarLocalStorageImple
    private let stubRemote: StubRemoteAPI
    
    init() {
        self.stubRemote = .init(responses: DummyResponse().reponse)
        self.cacheStorage = .init(sqliteService: self.sqliteService)
    }
    
    private func makeRepository() -> GoogleCalendarRepositoryImple {
        return .init(
            remote: self.stubRemote,
            cacheStorage: self.cacheStorage
        )
    }
}


extension GoogleCalendarRepositoryImple_Tests {
    
    @Test func repository_loadColors() async throws {
        try await self.runTestWithOpenClose("test_google_1") {
            // given
            let expect = self.expectConfirm("color 로드")
            let repository = self.makeRepository()
            
            // when
            let colors = try await self.outputs(expect, for: repository.loadColors())
            
            // then
            #expect(colors.count == 1)
            #expect(colors.first?.calendars.count == 24)
            #expect(colors.first?.events.count == 11)
        }
    }
    
    @Test func repository_whenAfterLoadColors_updateCache() async throws {
        try await self.runTestWithOpenClose("test_google_2") {
            // given
            let expect = self.expectConfirm("color 로드 이후에 캐시 업데이트")
            let repository = self.makeRepository()
            
            // when
            let cacheBeforeLoad = try await self.cacheStorage.loadColors()
            let _ = try await self.outputs(expect, for: repository.loadColors())
            let cachedAfterLoad = try await self.cacheStorage.loadColors()
            
            // then
            #expect(cacheBeforeLoad == nil)
            #expect(cachedAfterLoad != nil)
        }
    }
    
    @Test func reposiotry_loadColorsWithCached() async throws {
        try await self.runTestWithOpenClose("test_google_3") {
            // given
            try await self.stubColorCache()
            let expect = self.expectConfirm("캐시 있는 상태에서 color 조회")
            expect.count = 2
            let repository = self.makeRepository()
            
            // when
            let colors = try await self.outputs(expect, for: repository.loadColors())
            
            // then
            #expect(colors.count == 2)
            #expect(colors.map { $0.calendars.count } == [1, 24])
            #expect(colors.map { $0.events.count } == [0, 11])
        }
    }
    
    private func stubColorCache() async throws {
        let color = GoogleCalendar.Colors(
            calendars: ["1": .init(foregroundHex: "fore", backgroudHex: "back")],
            events: [:]
        )
        try await self.cacheStorage.updateColors(color)
    }
}

extension GoogleCalendarRepositoryImple_Tests {
    
    // load calendar list
    @Test func repository_loadCalendarTag() async throws {
        try await self.runTestWithOpenClose("test_google_tag_1") {
            // given
            let expect = self.expectConfirm("캘린더 태그 조회")
            expect.count = 2
            let repository = self.makeRepository()
            
            // when
            let tagLists = try await self.outputs(expect, for: repository.loadCalendarTags())
            
            // then
            #expect(tagLists.count == 2)
            #expect(tagLists.first?.isEmpty == true)
            
            let tag = tagLists.last?.last
            self.assertTagFromRemote(tag)
        }
    }
    
    // load calendar with cache
    @Test func repository_loadCalendarTag_withCache() async throws {
        try await self.runTestWithOpenClose("test_google_tag_2") {
            // given
            try await self.stubCalendarTag()
            let expect = self.expectConfirm("캐시와 함께 캘린더 태그 조회")
            expect.count = 2
            let repository = self.makeRepository()
            
            // when
            let tagLists = try await self.outputs(expect, for: repository.loadCalendarTags())
            
            // then
            #expect(tagLists.count == 2)
            let cached = tagLists.first
            #expect(cached?.first?.name == "old")
            #expect(cached?.first?.isSelected == false)
            
            let refreshed = tagLists.last
            self.assertTagFromRemote(refreshed?.last)
        }
    }
    
    // load calendar list + refresh cache
    @Test func repository_whenAfterLoadCalendarList_refreshCache() async throws {
        try await self.runTestWithOpenClose("test_google_tag_3") {
            // given
            let expect = self.expectConfirm("캘린더 태그 조회 이후에 캐시 업데이트")
            expect.count = 2
            let repository = self.makeRepository()
            
            // when
            let tagList = try await self.outputs(expect, for: repository.loadCalendarTags())
            
            // then
            let tagFromRemote = tagList.last?.last
            let refreshedCached = try await self.cacheStorage.loadCalendarList().last
            self.assertTagFromRemote(tagFromRemote)
            self.assertTagFromRemote(refreshedCached)
        }
    }
    
    private func stubCalendarTag() async throws {
        let calendars: [GoogleCalendar.Tag] = [
            .init(id: "old", name: "old")
        ]
        try await self.cacheStorage.updateCalendarList(calendars)
    }
    
    private func assertTagFromRemote(_ tag: GoogleCalendar.Tag?) {
        #expect(tag?.id == "some@gmail.com")
        #expect(tag?.name == "some@gmail.com")
        #expect(tag?.description == nil)
        #expect(tag?.backgroundColorHex == "#fad165")
        #expect(tag?.foregroundColorHex == "#000000")
        #expect(tag?.colorId == "12")
        #expect(tag?.isSelected == true)
    }
}

// MARK: - events

extension GoogleCalendarRepositoryImple_Tests {
    
    private var range: Range<TimeInterval> {
        let start = "2025.04.01 00:00:00".date()
        let end = "2025.05.01 00:00:00".date()
        return (start.timeIntervalSince1970..<end.timeIntervalSince1970)
    }
    
    @Test func repository_loadEventsWithoutCache() async throws {
        try await self.runTestWithOpenClose("test_google_event_1") {
            // given
            let expect = self.expectConfirm("캐시 없는 상태에서 remote에서 이벤트 조회 -> 주어진 기간내 자동으로 페이징")
            expect.count = 1
            expect.timeout = .milliseconds(100)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEvents("c_id", in: self.range)
            let eventLists = try await self.outputs(expect, for: load)
            
            // then
            try #require(eventLists.count == 1)
            
            let eventFromCache = eventLists.first
            #expect(eventFromCache?.isEmpty != true)
            
            let eventFromRemote = eventLists.last
            let ids = eventFromRemote?.map { $0.eventId }
            #expect(ids == [
                "time_is_date", "out_of_period", "time_is_dateTime", "second_page_event"
            ])
            self.assertEventTimeIsDate(eventFromRemote?.first)
        }
    }
    
    @Test func repository_loadEvents_witHCache() async throws {
        try await self.runTestWithOpenClose("test_google_event_2") {
            // given
            try await self.saveCache()
            let expect = self.expectConfirm("캐시 있는 상태에서 조회시, 캐시값 먼저 나가고, 이후 리모트값 나감")
            expect.count = 2
            expect.timeout = .milliseconds(1000)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEvents("c_id", in: self.range)
            let eventLists = try await self.outputs(expect, for: load)
            
            // then
            try #require(eventLists.count == 2)
            let eventFromCache = eventLists.first
            #expect(eventFromCache?.map { $0.eventId } == ["time_is_date"])
            #expect(eventFromCache?.map { $0.name } == ["old"])
            #expect(eventFromCache?.map { $0.colorId } == ["color"])
            #expect(eventFromCache?.map { $0.htmlLink } == ["link"])
            
            let eventFromRemote = eventLists.last
            #expect(eventFromRemote?.map { $0.eventId } == [
                "time_is_date", "out_of_period", "time_is_dateTime", "second_page_event"
            ])
            let name = eventFromRemote?.first(where: { $0.eventId == "time_is_date" })?.name
            #expect(name == "하루죙일")
        }
    }
    
    // remote 조회시에 로컬에 저장
    @Test func repository_whenAfterLoadEvents_updateCache() async throws {
        try await self.runTestWithOpenClose("test_google_event_3") {
            // given
            try await self.saveCache()
            let expect = self.expectConfirm("이벤트 조회 이후에 캐시 업데이트")
            expect.count = 2
            expect.timeout = .milliseconds(100)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEvents("c_id", in: self.range)
            let eventLists = try await self.outputs(expect, for: load)
            try #require(eventLists.count == 2)
            
            let eventsFromCache = try await self.cacheStorage.loadEvents("c_id", self.range)
            
            // then
            let ids = eventsFromCache.map { $0.eventId }
            #expect(ids == [
                "time_is_date", "time_is_dateTime", "second_page_event"
            ])
            self.assertEventTimeIsDate(eventsFromCache.first)
        }
    }
    
    // 이벤트 상세 조회시, 캐싱된 값 먼저 나가고, 리모트에서 새로 조회된값 나감
    @Test func repository_loadEventDetail() async throws {
        try await self.runTestWithOpenClose("test_google_event_4") {
            // given
            try await self.saveCache()
            let expect = self.expectConfirm("이벤트 상세 조회시, 캐싱된 값 먼저 나가고, 리모트에서 새로 조회된값 나감")
            expect.count = 2
            expect.timeout = .milliseconds(100)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEventDetail("c_id", "Asia/Seoul", "time_is_date")
            let details = try await self.outputs(expect, for: load)
            let refreshedCache = try await self.cacheStorage.loadEventDetail("time_is_date")
            
            // then
            try #require(details.count == 2)
            let cached = details.first
            let refreshed = details.last
            
            #expect(cached?.summary == "old")
            self.assertEventOrigin(refreshed)
            self.assertEventOrigin(refreshedCache)
        }
    }
    
    private func assertEventTimeIsDate(_ event: GoogleCalendar.Event?) {
        #expect(event?.eventId == "time_is_date")
        #expect(event?.calendarId == "c_id")
        #expect(event?.name == "하루죙일")
        
        let kst = TimeZone(identifier: "Asia/Seoul")!
        let start = "2025-04-11".asAllDayDate(kst)!
        let end = "2025-04-12".asAllDayDate(kst)!
        let time = EventTime.allDay(
            start.timeIntervalSince1970..<end.timeIntervalSince1970,
            secondsFromGMT: TimeInterval(kst.secondsFromGMT())
        )
        #expect(time == event?.eventTime)
    }
    
    private func assertEventOrigin(_ origin: GoogleCalendar.EventOrigin?) {
        #expect(origin?.id == "time_is_date")
        #expect(origin?.summary == "하루죙일")
        #expect(origin?.htmlLink == "https://www.google.com/calendar/event?eid=M241a2Y2dWk5bWM2M3Vqa3I4b3JsOWR0bjggZ2Vhcm1hbW4wNkBt")
        #expect(origin?.description == "description")
        #expect(origin?.location == "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea")
        #expect(origin?.colorId == "2")
        
        let creator = origin?.creator
        #expect(creator?.id == nil)
        #expect(creator?.email == "gearmamn06@gmail.com")
        #expect(creator?.displayName == nil)
        #expect(creator?.`self` == true)
        
        let organizer = origin?.organizer
        #expect(organizer?.id == nil)
        #expect(organizer?.email == "gearmamn06@gmail.com")
        #expect(organizer?.displayName == nil)
        #expect(organizer?.`self` == true)
        
        let start = origin?.start
        #expect(start?.date == "2025-04-11")
        #expect(start?.dateTime == nil)
        #expect(start?.timeZone == nil)
        
        let end = origin?.end
        #expect(end?.date == "2025-04-12")
        #expect(end?.dateTime == nil)
        #expect(end?.timeZone == nil)
        
        #expect(origin?.endTimeUnspecified == nil)
        #expect(origin?.recurrence == ["RRULE:FREQ=DAILY;COUNT=3"])
        #expect(origin?.recurringEventId == "origin")
        #expect(origin?.sequence == 0)
        
        #expect(origin?.attendees == nil)
        #expect(origin?.hangoutLink == "https://meet.google.com/piw-hphe-juu")
        
        let conf = origin?.conferenceData
        #expect(conf?.conferenceId == "piw-hphe-juu")
        let point = conf?.entryPoints?.first
        #expect(point?.entryPointType == "video")
        #expect(point?.uri == "https://meet.google.com/piw-hphe-juu")
        #expect(point?.label == "meet.google.com/piw-hphe-juu")
        
        #expect(origin?.attachments == nil)
        #expect(origin?.eventType == "default")
        
        #expect(origin?.status == .confirmed)
    }
    
    private var dummyOldEventListsAndEvents: (GoogleCalendar.EventOriginValueList, GoogleCalendar.Event) {
        
        let start = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.date .~ "2025-04-11"
        let end = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.date .~ "2025-04-12"
        let origin = GoogleCalendar.EventOrigin(id: "time_is_date", summary: "old")
            |> \.start .~ start
            |> \.end .~ end
            |> \.colorId .~ "color"
            |> \.htmlLink .~ "link"
        let timeZone = "Asia/Seoul"
        let originEvent = GoogleCalendar.Event(origin, "c_id", timeZone)!
        let list = GoogleCalendar.EventOriginValueList()
            |> \.timeZone .~ timeZone
            |> \.items .~ [origin]
        
        return (list, originEvent)
    }
    
    private func saveCache() async throws {
        let (list, event) = self.dummyOldEventListsAndEvents
        try await self.cacheStorage.updateEvents("c_id", list, [event])
    }
}

private struct DummyResponse {
    
    var reponse: [StubRemoteAPI.Response] {
        return [
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.colors,
                header: [:],
                resultJsonString: .success(self.dummyColors)
            ),
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.calednarList,
                resultJsonString: .success(self.dummyCalednarList)
            ),
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.eventList(calendarId: "c_id"),
                parameters: ["pageToken": "next"],
                parameterCompare: { _, params in params["pageToken"] as? String == "next" },
                resultJsonString: .success(self.dummyEventListPage2)
            ),
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.eventList(calendarId: "c_id"),
                parameters: [:],
                parameterCompare: { _, params in params["pageToken"] as? String == nil },
                resultJsonString: .success(self.dummyEventListPage1)
            ),
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "time_is_date"),
                resultJsonString: .success(self.dummyNewEvent("time_is_date"))
            ),
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "origin"),
                resultJsonString: .success(
                    self.dummyNewEvent("origin", isRepeatOrigin: true)
                )
            )
        ]
    }
    
    private var dummyColors: String {
        return """
        {
         "kind": "calendar#colors",
         "updated": "2012-02-14T00:00:00.000Z",
         "calendar": {
          "1": {
           "background": "#ac725e",
           "foreground": "#1d1d1d"
          },
          "2": {
           "background": "#d06b64",
           "foreground": "#1d1d1d"
          },
          "3": {
           "background": "#f83a22",
           "foreground": "#1d1d1d"
          },
          "4": {
           "background": "#fa573c",
           "foreground": "#1d1d1d"
          },
          "5": {
           "background": "#ff7537",
           "foreground": "#1d1d1d"
          },
          "6": {
           "background": "#ffad46",
           "foreground": "#1d1d1d"
          },
          "7": {
           "background": "#42d692",
           "foreground": "#1d1d1d"
          },
          "8": {
           "background": "#16a765",
           "foreground": "#1d1d1d"
          },
          "9": {
           "background": "#7bd148",
           "foreground": "#1d1d1d"
          },
          "10": {
           "background": "#b3dc6c",
           "foreground": "#1d1d1d"
          },
          "11": {
           "background": "#fbe983",
           "foreground": "#1d1d1d"
          },
          "12": {
           "background": "#fad165",
           "foreground": "#1d1d1d"
          },
          "13": {
           "background": "#92e1c0",
           "foreground": "#1d1d1d"
          },
          "14": {
           "background": "#9fe1e7",
           "foreground": "#1d1d1d"
          },
          "15": {
           "background": "#9fc6e7",
           "foreground": "#1d1d1d"
          },
          "16": {
           "background": "#4986e7",
           "foreground": "#1d1d1d"
          },
          "17": {
           "background": "#9a9cff",
           "foreground": "#1d1d1d"
          },
          "18": {
           "background": "#b99aff",
           "foreground": "#1d1d1d"
          },
          "19": {
           "background": "#c2c2c2",
           "foreground": "#1d1d1d"
          },
          "20": {
           "background": "#cabdbf",
           "foreground": "#1d1d1d"
          },
          "21": {
           "background": "#cca6ac",
           "foreground": "#1d1d1d"
          },
          "22": {
           "background": "#f691b2",
           "foreground": "#1d1d1d"
          },
          "23": {
           "background": "#cd74e6",
           "foreground": "#1d1d1d"
          },
          "24": {
           "background": "#a47ae2",
           "foreground": "#1d1d1d"
          }
         },
         "event": {
          "1": {
           "background": "#a4bdfc",
           "foreground": "#1d1d1d"
          },
          "2": {
           "background": "#7ae7bf",
           "foreground": "#1d1d1d"
          },
          "3": {
           "background": "#dbadff",
           "foreground": "#1d1d1d"
          },
          "4": {
           "background": "#ff887c",
           "foreground": "#1d1d1d"
          },
          "5": {
           "background": "#fbd75b",
           "foreground": "#1d1d1d"
          },
          "6": {
           "background": "#ffb878",
           "foreground": "#1d1d1d"
          },
          "7": {
           "background": "#46d6db",
           "foreground": "#1d1d1d"
          },
          "8": {
           "background": "#e1e1e1",
           "foreground": "#1d1d1d"
          },
          "9": {
           "background": "#5484ed",
           "foreground": "#1d1d1d"
          },
          "10": {
           "background": "#51b749",
           "foreground": "#1d1d1d"
          },
          "11": {
           "background": "#dc2127",
           "foreground": "#1d1d1d"
          }
         }
        }
        """
    }
    
    private var dummyCalednarList: String {
        return """
        {
         "kind": "calendar#calendarList",
         "etag": "p334bv9sfmuuom0o",
         "nextSyncToken": "CMi_p4-3vYsDEhRnZWFybWFtbjA2QGdtYWlsLmNvbQ==",
         "items": [
          {
           "kind": "calendar#calendarListEntry",
           "etag": "1438945356869000",
           "id": "ko.south_korea#holiday@group.v.calendar.google.com",
           "summary": "대한민국의 휴일",
           "description": "대한민국의 공휴일",
           "timeZone": "Asia/Seoul",
           "colorId": "9",
           "backgroundColor": "#7bd148",
           "foregroundColor": "#000000",
           "selected": true,
           "accessRole": "reader",
           "defaultReminders": [],
           "conferenceProperties": {
            "allowedConferenceSolutionTypes": [
             "hangoutsMeet"
            ]
           }
          },
          {
           "kind": "calendar#calendarListEntry",
           "etag": "1504143860660000",
           "id": "some@gmail.com",
           "summary": "some@gmail.com",
           "timeZone": "Asia/Seoul",
           "colorId": "12",
           "backgroundColor": "#fad165",
           "foregroundColor": "#000000",
           "selected": true,
           "accessRole": "owner",
           "defaultReminders": [
            {
             "method": "popup",
             "minutes": 30
            },
            {
             "method": "email",
             "minutes": 30
            }
           ],
           "notificationSettings": {
            "notifications": [
             {
              "type": "eventCreation",
              "method": "email"
             },
             {
              "type": "eventChange",
              "method": "email"
             },
             {
              "type": "eventCancellation",
              "method": "email"
             },
             {
              "type": "eventResponse",
              "method": "email"
             }
            ]
           },
           "primary": true,
           "conferenceProperties": {
            "allowedConferenceSolutionTypes": [
             "hangoutsMeet"
            ]
           }
          }
         ]
        }
        """
    }
    
    private func dummyNewEvent(_ id: String, isRepeatOrigin: Bool = false) -> String {
        let repeatOriginRecurrence = """
        "recurrence": [
          "RRULE:FREQ=DAILY;COUNT=3"
         ],
        """
        let notRepeatOriginRecurrence = """
        "recurringEventId": "origin",    
        """
        return """
        {
         "kind": "calendar#event",
         "etag": "\\"3489807262385694\\"",
         "id": "\(id)",
         "status": "confirmed",
         "htmlLink": "https://www.google.com/calendar/event?eid=M241a2Y2dWk5bWM2M3Vqa3I4b3JsOWR0bjggZ2Vhcm1hbW4wNkBt",
        \(isRepeatOrigin ? repeatOriginRecurrence : notRepeatOriginRecurrence)
         "created": "2025-04-17T15:27:11.000Z",
         "updated": "2025-04-17T15:27:11.192Z",
         "summary": "하루죙일",
         "description": "description",
         "location": "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea",
         "colorId": "2",
         "creator": {
          "email": "gearmamn06@gmail.com",
          "self": true
         },
         "organizer": {
          "email": "gearmamn06@gmail.com",
          "self": true
         },
         "start": {
          "date": "2025-04-11"
         },
         "end": {
          "date": "2025-04-12"
         },
         "transparency": "transparent",
         "iCalUID": "3n5kf6ui9mc63ujkr8orl9dtn8@google.com",
         "sequence": 0,
         "hangoutLink": "https://meet.google.com/piw-hphe-juu",
         "conferenceData": {
          "entryPoints": [
           {
            "entryPointType": "video",
            "uri": "https://meet.google.com/piw-hphe-juu",
            "label": "meet.google.com/piw-hphe-juu"
           }
          ],
          "conferenceSolution": {
           "key": {
            "type": "hangoutsMeet"
           },
           "name": "Google Meet",
           "iconUri": "https://fonts.gstatic.com/s/i/productlogos/meet_2020q4/v6/web-512dp/logo_meet_2020q4_color_2x_web_512dp.png"
          },
          "conferenceId": "piw-hphe-juu"
         },
         "reminders": {
          "useDefault": false,
          "overrides": [
           {
            "method": "popup",
            "minutes": 30
           },
           {
            "method": "email",
            "minutes": 450
           }
          ]
         },
         "eventType": "default"
        }
        """
    }
    
    private var dummyEventListPage1: String {
        return """
        {
         "kind": "calendar#events",
         "etag": "\\"p327p1akgnbfoo0o\\"",
         "summary": "gearmamn06@gmail.com",
         "description": "",
         "updated": "2025-04-17T16:09:57.043Z",
         "timeZone": "Asia/Seoul",
         "accessRole": "owner",
         "defaultReminders": [
          {
           "method": "popup",
           "minutes": 30
          },
          {
           "method": "email",
           "minutes": 30
          }
         ],
         "nextSyncToken": "CI-QqpC634wDEI-QqpC634wDGAUg5r_L5AIo5r_L5AI=",
         "nextPageToken": "next",
         "items": [
          {
           "kind": "calendar#event",
           "etag": "\\"3489807262385694\\"",
           "id": "time_is_date",
           "status": "confirmed",
           "htmlLink": "https://www.google.com/calendar/event?eid=M241a2Y2dWk5bWM2M3Vqa3I4b3JsOWR0bjggZ2Vhcm1hbW4wNkBt",
           "created": "2025-04-17T15:27:11.000Z",
           "updated": "2025-04-17T15:27:11.192Z",
           "summary": "하루죙일",
           "description": "description",
           "location": "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea",
           "colorId": "2",
           "creator": {
            "email": "gearmamn06@gmail.com",
            "self": true
           },
           "organizer": {
            "email": "gearmamn06@gmail.com",
            "self": true
           },
           "start": {
            "date": "2025-04-11"
           },
           "end": {
            "date": "2025-04-12"
           },
           "transparency": "transparent",
           "iCalUID": "3n5kf6ui9mc63ujkr8orl9dtn8@google.com",
           "sequence": 0,
           "hangoutLink": "https://meet.google.com/piw-hphe-juu",
           "conferenceData": {
            "entryPoints": [
             {
              "entryPointType": "video",
              "uri": "https://meet.google.com/piw-hphe-juu",
              "label": "meet.google.com/piw-hphe-juu"
             }
            ],
            "conferenceSolution": {
             "key": {
              "type": "hangoutsMeet"
             },
             "name": "Google Meet",
             "iconUri": "https://fonts.gstatic.com/s/i/productlogos/meet_2020q4/v6/web-512dp/logo_meet_2020q4_color_2x_web_512dp.png"
            },
            "conferenceId": "piw-hphe-juu"
           },
           "reminders": {
            "useDefault": false,
            "overrides": [
             {
              "method": "popup",
              "minutes": 30
             },
             {
              "method": "email",
              "minutes": 450
             }
            ]
           },
           "eventType": "default"
          }, 
          {
           "kind": "calendar#event",
           "etag": "\\"3489807262385694\\"",
           "id": "out_of_period",
           "status": "confirmed",
           "summary": "2026년도 일정",
           "start": {
            "date": "2026-04-11"
           },
           "end": {
            "date": "2026-04-12"
           }
          }, 
          {
           "kind": "calendar#event",
           "etag": "\\"3489807262385694\\"",
           "id": "time_is_dateTime",
           "status": "confirmed",
           "summary": "특정시간 일정",
           "start": {
                "dateTime": "2025-04-09T14:00:00+09:00",
                "timeZone": "Asia/Seoul"
           },
           "end": {
                "dateTime": "2025-04-09T15:00:00+09:00",
                "timeZone": "Asia/Seoul"
            }
          }
         ]
        }
        """
    }
    
    private var dummyEventListPage2: String {
        return """
        {
         "kind": "calendar#events",
         "etag": "\\"p327p1akgnbfoo0o\\"",
         "summary": "gearmamn06@gmail.com",
         "description": "",
         "updated": "2025-04-17T16:09:57.043Z",
         "timeZone": "Asia/Seoul",
         "accessRole": "owner",
         "defaultReminders": [
          {
           "method": "popup",
           "minutes": 30
          },
          {
           "method": "email",
           "minutes": 30
          }
         ],
         "nextSyncToken": "CI-QqpC634wDEI-QqpC634wDGAUg5r_L5AIo5r_L5AI=",
         "items": [
          {
           "kind": "calendar#event",
           "etag": "\\"3489807262385694\\"",
           "id": "second_page_event",
           "status": "confirmed",
           "htmlLink": "https://www.google.com/calendar/event?eid=M241a2Y2dWk5bWM2M3Vqa3I4b3JsOWR0bjggZ2Vhcm1hbW4wNkBt",
           "created": "2025-04-17T15:27:11.000Z",
           "updated": "2025-04-17T15:27:11.192Z",
           "summary": "두번째 페이지 - 하루죙일",
           "description": "description",
           "location": "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea",
           "colorId": "2",
           "creator": {
            "email": "gearmamn06@gmail.com",
            "self": true
           },
           "organizer": {
            "email": "gearmamn06@gmail.com",
            "self": true
           },
           "start": {
            "date": "2025-04-11"
           },
           "end": {
            "date": "2025-04-12"
           },
           "transparency": "transparent",
           "iCalUID": "3n5kf6ui9mc63ujkr8orl9dtn8@google.com",
           "sequence": 0,
           "hangoutLink": "https://meet.google.com/piw-hphe-juu",
           "conferenceData": {
            "entryPoints": [
             {
              "entryPointType": "video",
              "uri": "https://meet.google.com/piw-hphe-juu",
              "label": "meet.google.com/piw-hphe-juu"
             }
            ],
            "conferenceSolution": {
             "key": {
              "type": "hangoutsMeet"
             },
             "name": "Google Meet",
             "iconUri": "https://fonts.gstatic.com/s/i/productlogos/meet_2020q4/v6/web-512dp/logo_meet_2020q4_color_2x_web_512dp.png"
            },
            "conferenceId": "piw-hphe-juu"
           },
           "reminders": {
            "useDefault": false,
            "overrides": [
             {
              "method": "popup",
              "minutes": 30
             },
             {
              "method": "email",
              "minutes": 450
             }
            ]
           },
           "eventType": "default"
          }
         ]
        }
        """
    }
}

private extension String {
    
    func asAllDayDate(_ timeZone: TimeZone) -> Date? {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [
            .withFullDate, .withDashSeparatorInDate
        ]
        dateFormatter.timeZone = timeZone
        return dateFormatter.date(from: self)
    }
}
