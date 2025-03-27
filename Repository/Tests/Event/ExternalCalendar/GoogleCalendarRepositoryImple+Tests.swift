//
//  GoogleCalendarRepositoryImple+Tests.swift
//  RepositoryTests
//
//  Created by sudo.park on 2/9/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import SQLiteService
import UnitTestHelpKit

@testable import Repository


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
}
