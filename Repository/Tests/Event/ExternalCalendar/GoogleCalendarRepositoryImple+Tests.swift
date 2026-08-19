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
import Extensions
import SQLiteService
import UnitTestHelpKit

@testable import Repository


@Suite("GoogleCalendarRepositoryImple_Tests", .serialized)
final class GoogleCalendarRepositoryImple_Tests: PublisherWaitable, LocalTestable {
    
    var cancelBag: Set<AnyCancellable>! = []
    let sqliteService: SQLiteService = .init()
    let cacheStorage: GoogleCalendarLocalStorageImple
    private let stubRemote: StubRemoteAPI
    private let testAccountId = "test@google.com"

    init() {
        self.stubRemote = .init(responses: DummyResponse().reponse)
        let pool = StubExternalCalendarSQLiteConnectionPool(self.sqliteService)
        self.cacheStorage = .init(connectionPool: pool)
    }

    private func makeRepository() -> GoogleCalendarRepositoryImple {
        return .init(
            remote: self.stubRemote,
            cacheStorage: self.cacheStorage,
            accountId: self.testAccountId
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
            let cacheBeforeLoad = try await self.cacheStorage.loadColors(accountId: self.testAccountId)
            let _ = try await self.outputs(expect, for: repository.loadColors())
            let cachedAfterLoad = try await self.cacheStorage.loadColors(accountId: self.testAccountId)
            
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
            ownerId: testAccountId,
            calendars: ["1": .init(foregroundHex: "fore", backgroudHex: "back")],
            events: [:]
        )
        try await self.cacheStorage.updateColors(color, accountId: self.testAccountId)
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
            let refreshedCached = try await self.cacheStorage.loadCalendarList(accountId: self.testAccountId).last
            self.assertTagFromRemote(tagFromRemote)
            self.assertTagFromRemote(refreshedCached)
        }
    }
    
    private func stubCalendarTag() async throws {
        let calendars: [GoogleCalendar.Tag] = [
            .init(id: "old", name: "old")
        ]
        try await self.cacheStorage.updateCalendarList(calendars, accountId: self.testAccountId)
    }
    
    private func assertTagFromRemote(_ tag: GoogleCalendar.Tag?) {
        #expect(tag?.id == "some@gmail.com")
        #expect(tag?.name == "some@gmail.com")
        #expect(tag?.description == nil)
        #expect(tag?.backgroundColorHex == "#fad165")
        #expect(tag?.foregroundColorHex == "#000000")
        #expect(tag?.colorId == "12")
        #expect(tag?.isSelected == true)
        #expect(tag?.accessRole == .owner)
    }
}

// MARK: - accessRole 저장/복원

extension GoogleCalendarRepositoryImple_Tests {

    @Test func cacheStorage_saveAndLoad_preservesOwnerAccessRole() async throws {
        try await self.runTestWithOpenClose("test_google_access_role_1") {
            // given
            let tag = GoogleCalendar.Tag(id: "owner_calendar", name: "owner calendar")
                |> \.accessRole .~ .owner

            // when
            try await self.cacheStorage.updateCalendarList([tag], accountId: self.testAccountId)
            let loaded = try await self.cacheStorage.loadCalendarList(accountId: self.testAccountId)

            // then
            #expect(loaded.first?.accessRole == .owner)
            #expect(loaded.first?.isWritable == true)
        }
    }

    @Test func cacheStorage_saveAndLoad_preservesReaderAccessRole() async throws {
        try await self.runTestWithOpenClose("test_google_access_role_2") {
            // given
            let tag = GoogleCalendar.Tag(id: "reader_calendar", name: "reader calendar")
                |> \.accessRole .~ .reader

            // when
            try await self.cacheStorage.updateCalendarList([tag], accountId: self.testAccountId)
            let loaded = try await self.cacheStorage.loadCalendarList(accountId: self.testAccountId)

            // then
            #expect(loaded.first?.accessRole == .reader)
            #expect(loaded.first?.isWritable == false)
        }
    }

    @Test func cacheStorage_saveAndLoad_withNilAccessRole_doesNotShiftOtherColumns() async throws {
        try await self.runTestWithOpenClose("test_google_access_role_3") {
            // given
            let tag = GoogleCalendar.Tag(id: "no_role_calendar", name: "no role calendar")
                |> \.colorId .~ "12"
                |> \.isSelected .~ true

            // when
            try await self.cacheStorage.updateCalendarList([tag], accountId: self.testAccountId)
            let loaded = try await self.cacheStorage.loadCalendarList(accountId: self.testAccountId)

            // then
            #expect(loaded.first?.accessRole == nil)
            #expect(loaded.first?.isWritable == false)
            #expect(loaded.first?.name == "no role calendar")
            #expect(loaded.first?.colorId == "12")
            #expect(loaded.first?.isSelected == true)
        }
    }

    @Test func mapper_whenAccessRoleIsUnrecognizedValue_decodesAsNilButOtherFieldsSurvive() throws {
        // given
        let json = """
        {
            "id": "future_role_calendar",
            "summary": "future role calendar",
            "colorId": "5",
            "selected": true,
            "accessRole": "futureRoleNotYetSupported"
        }
        """.data(using: .utf8)!

        // when
        let mapper = try JSONDecoder().decode(GoogleCalendarEventTagMapper.self, from: json)

        // then
        #expect(mapper.calendar.id == "future_role_calendar")
        #expect(mapper.calendar.colorId == "5")
        #expect(mapper.calendar.isSelected == true)
        #expect(mapper.calendar.accessRole == nil)
        #expect(mapper.calendar.isWritable == false)
    }

    @Test func migration_addsAccessRoleColumn_toExistingTable_withoutLosingData() async throws {
        try await self.runTestWithOpenClose("test_google_access_role_migration") {
            // given
            let legacyTag = GoogleCalendar.Tag(id: "legacy_calendar", name: "legacy calendar")
                |> \.colorId .~ "9"
                |> \.isSelected .~ true
            try await self.sqliteService.async.run { db in
                try db.createTableOrNot(GoogleCalendarEventTagTableV0LegacyTable.self)
                let entity = GoogleCalendarEventTagTable.Entity(accountId: self.testAccountId, legacyTag)
                try db.insert(GoogleCalendarEventTagTableV0LegacyTable.self, entities: [entity], shouldReplace: true)
            }

            // when
            try await self.sqliteService.async.run { db in
                try GoogleCalendarEventTagTableMigration.runMigration(for: 0, database: db)
            }
            let migratedInTag = GoogleCalendar.Tag(id: "migrated_in_calendar", name: "migrated in calendar")
                |> \.accessRole .~ .owner
            try await self.sqliteService.async.run { db in
                let entity = GoogleCalendarEventTagTable.Entity(accountId: self.testAccountId, migratedInTag)
                try db.insert(GoogleCalendarEventTagTable.self, entities: [entity], shouldReplace: false)
            }
            let loaded = try await self.cacheStorage.loadCalendarList(accountId: self.testAccountId)

            // then
            let legacy = loaded.first { $0.id == "legacy_calendar" }
            #expect(legacy?.colorId == "9")
            #expect(legacy?.isSelected == true)
            #expect(legacy?.accessRole == nil)

            let migratedIn = loaded.first { $0.id == "migrated_in_calendar" }
            #expect(migratedIn?.accessRole == .owner)
        }
    }

    @Test func migration_whenTableNotCreatedYet_succeedsAndTableAcceptsAccessRole() async throws {
        try await self.runTestWithOpenClose("test_google_access_role_migration_fresh") {
            // given - 신규 설치: 캘린더 목록을 아직 한 번도 로드하지 않아 테이블이 없다

            // when
            try await self.sqliteService.async.run { db in
                try GoogleCalendarEventTagTableMigration.runMigration(for: 0, database: db)
            }

            // then
            let tag = GoogleCalendar.Tag(id: "fresh_calendar", name: "fresh calendar")
                |> \.accessRole .~ .writer
            try await self.sqliteService.async.run { db in
                let entity = GoogleCalendarEventTagTable.Entity(accountId: self.testAccountId, tag)
                try db.insert(GoogleCalendarEventTagTable.self, entities: [entity], shouldReplace: false)
            }
            let loaded = try await self.cacheStorage.loadCalendarList(accountId: self.testAccountId)
            #expect(loaded.first?.id == "fresh_calendar")
            #expect(loaded.first?.accessRole == .writer)
        }
    }
}

private struct GoogleCalendarEventTagTableV0LegacyTable: Table {

    enum Columns: String, TableColumn {
        case accountId = "account_id"
        case tagId = "tag_id"
        case name
        case description
        case background
        case foreground
        case colorId = "color_id"
        case isSelected = "is_selected"

        var dataType: ColumnDataType {
            switch self {
            case .accountId: return .text([.notNull])
            case .tagId: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .name: return .text([.notNull])
            case .description: return .text([])
            case .background: return .text([])
            case .foreground: return .text([])
            case .colorId: return .text([])
            case .isSelected: return .integer([])
            }
        }
    }

    typealias ColumnType = Columns
    typealias EntityType = GoogleCalendarEventTagTable.Entity
    static var tableName: String { GoogleCalendarEventTagTable.tableName }

    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .accountId: return entity.accountId
        case .tagId: return entity.tag.id
        case .name: return entity.tag.name
        case .description: return entity.tag.description
        case .background: return entity.tag.backgroundColorHex
        case .foreground: return entity.tag.foregroundColorHex
        case .colorId: return entity.tag.colorId
        case .isSelected: return entity.tag.isSelected ?? false
        }
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
            expect.count = 2
            expect.timeout = .seconds(1)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEvents("c_id", in: self.range)
            let eventLists = try await self.outputs(expect, for: load)
            
            // then
            let eventFromCache = eventLists.first
            #expect(eventFromCache?.isEmpty == true)
            
            let eventFromRemote = eventLists.last
            let ids = eventFromRemote?.map { $0.eventId }
            #expect(ids == [
                "time_is_date", "out_of_period", "time_is_dateTime", "second_page_event"
            ])
            #expect(eventFromRemote?.allSatisfy { $0.accountId == self.testAccountId } == true)
            self.assertEventTimeIsDate(eventFromRemote?.first)
        }
    }
    
    @Test func repository_loadEvents_withCache() async throws {
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
            #expect(eventFromCache?.map { $0.location } == [
                "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea"
            ])
            #expect(eventFromCache?.allSatisfy { $0.accountId == self.testAccountId } == true)

            let eventFromRemote = eventLists.last
            #expect(eventFromRemote?.map { $0.eventId } == [
                "time_is_date", "out_of_period", "time_is_dateTime", "second_page_event"
            ])
            #expect(eventFromRemote?.allSatisfy { $0.accountId == self.testAccountId } == true)
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
            expect.timeout = .seconds(1)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEvents("c_id", in: self.range)
            let eventLists = try await self.outputs(expect, for: load)
            try #require(eventLists.count == 2)
            
            let eventsFromCache = try await self.cacheStorage.loadEvents("c_id", self.range, accountId: self.testAccountId)
            
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
            expect.timeout = .seconds(1)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEventDetail("c_id", "Asia/Seoul", "time_is_date")
            let details = try await self.outputs(expect, for: load)
            let refreshedCache = try await self.cacheStorage.loadEventDetail("time_is_date", accountId: self.testAccountId)
            
            // then
            try #require(details.count == 2)
            let cached = details.first
            let refreshed = details.last
            
            #expect(cached?.summary == "old")
            self.assertEventOrigin(refreshed)
            self.assertEventOrigin(refreshedCache)
        }
    }
    
    @Test func repository_loadPrivateEvent() async throws {
        try await self.runTestWithOpenClose("test_google_event_5") {
            // given
            let expect = self.expectConfirm("비공개 이벤트 조회")
            expect.timeout = .seconds(1)
            let repository = self.makeRepository()
            
            // when
            let load = repository.loadEventDetail("c_id", "Asia/Seoul", "private_event")
            let details = try await self.outputs(expect, for: load)
            let refreshedCache = try await self.cacheStorage.loadEventDetail("private_event", accountId: self.testAccountId)
            
            // then
            try #require(details.count == 1)
            let remote = details.first
            #expect(remote?.summary == nil)
            #expect(remote?.summaryText == "external_service::google::hidden_event".localized())
            #expect(remote?.visibility == .private)
            
            #expect(refreshedCache.summary == "")
            #expect(refreshedCache.summaryText == "external_service::google::hidden_event".localized())
            #expect(refreshedCache.visibility == .private)
        }
    }
    
    private func assertEventTimeIsDate(_ event: GoogleCalendar.Event?) {
        #expect(event?.eventId == "time_is_date")
        #expect(event?.calendarId == "c_id")
        #expect(event?.name == "하루죙일")
        #expect(event?.location == "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea")
        
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
        
        #expect(origin?.attendees?.count == 1)
        #expect(origin?.attendees?.first?.email == "user1@email.com")
        #expect(origin?.attendees?.first?.organizer == true)
        #expect(origin?.attendees?.first?.selfValue == true)
        #expect(origin?.attendees?.first?.resource == true)
        #expect(origin?.attendees?.first?.responseStatus == "accepted")
        #expect(origin?.attendees?.first?.isAccepted == true)
        
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
        return self.dummyOldEventListAndEvent("time_is_date")
    }

    private func dummyOldEventListAndEvent(
        _ eventId: String
    ) -> (GoogleCalendar.EventOriginValueList, GoogleCalendar.Event) {

        let start = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.date .~ "2025-04-11"
        let end = GoogleCalendar.EventOrigin.GoogleEventTime()
            |> \.date .~ "2025-04-12"
        let origin = GoogleCalendar.EventOrigin(id: eventId, summary: "old")
            |> \.start .~ start
            |> \.end .~ end
            |> \.colorId .~ "color"
            |> \.htmlLink .~ "link"
            |> \.location .~ "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea"
        let timeZone = "Asia/Seoul"
        let originEvent = GoogleCalendar.Event(origin, "c_id", accountId: self.testAccountId, timeZone)!
        let list = GoogleCalendar.EventOriginValueList()
            |> \.timeZone .~ timeZone
            |> \.items .~ [origin]

        return (list, originEvent)
    }

    private func saveCache(_ eventId: String = "time_is_date") async throws {
        let (list, event) = self.dummyOldEventListAndEvent(eventId)
        try await self.cacheStorage.updateEvents("c_id", list, [event], accountId: self.testAccountId)
    }
}

// MARK: - write events

extension GoogleCalendarRepositoryImple_Tests {

    @Test func repository_updateEvent_sendsPatchWithOnlyEditedFields() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_1") {
            // given
            let expect = self.expectConfirm("이벤트 수정 요청")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.summary .~ "updated summary"

            // when
            let updated = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )

            // then
            #expect(self.stubRemote.didRequestedMethod == .patch)
            let requestedParams = try #require(self.stubRemote.didRequestedParams)
            #expect(requestedParams["summary"] as? String == "updated summary")
            #expect(requestedParams["start"] == nil)
            #expect(requestedParams["end"] == nil)
            #expect(requestedParams["location"] == nil)
            #expect(requestedParams["description"] == nil)
            #expect(requestedParams["colorId"] == nil)
            #expect(requestedParams["recurrence"] == nil)
            #expect(requestedParams["attendees"] == nil)
            #expect(requestedParams["conferenceData"] == nil)
            #expect(requestedParams["attachments"] == nil)

            self.assertUpdatedEventOrigin(updated)
        }
    }

    @Test func repository_updateEvent_updatesLocalCache() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_2") {
            // given
            try await self.saveCache()
            let expect = self.expectConfirm("이벤트 수정 후 로컬 캐시 갱신")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.summary .~ "updated summary"

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )
            let cached = try await self.cacheStorage.loadEventDetail("time_is_date", accountId: self.testAccountId)

            // then
            self.assertUpdatedEventOrigin(cached)
        }
    }

    @Test func repository_updateEvent_createsTimesCacheEntry_forAllDayEvent() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_3") {
            // given
            let expect = self.expectConfirm("all-day 이벤트 수정 후 기간조회용 캐시 생성")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.summary .~ "updated summary"

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )
            let cachedEvents = try await self.cacheStorage.loadEvents("c_id", self.range, accountId: self.testAccountId)

            // then
            #expect(cachedEvents.map { $0.eventId } == ["time_is_date"])
        }
    }

    @Test func repository_updateEventToAllDay_sendsNullDateTime() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_to_allday") {
            // given
            let expect = self.expectConfirm("시간 있는 이벤트를 종일로 바꾸면 dateTime 을 null 로 지운다")
            let repository = self.makeRepository()
            let start = GoogleCalendar.EventOrigin.GoogleEventTime() |> \.date .~ "2026-08-15"
            let end = GoogleCalendar.EventOrigin.GoogleEventTime() |> \.date .~ "2026-08-16"
            let params = GoogleCalendar.EventEditParams()
                |> \.start .~ start
                |> \.end .~ end

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )

            // then
            let requestedParams = try #require(self.stubRemote.didRequestedParams)
            let startJson = try #require(requestedParams["start"] as? [String: Any])
            #expect(startJson["date"] as? String == "2026-08-15")
            #expect(startJson["dateTime"] is NSNull)
            let endJson = try #require(requestedParams["end"] as? [String: Any])
            #expect(endJson["date"] as? String == "2026-08-16")
            #expect(endJson["dateTime"] is NSNull)
        }
    }

    @Test func repository_updateEventToTimed_sendsNullDate() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_to_timed") {
            // given
            let expect = self.expectConfirm("종일 이벤트를 시간 있는 이벤트로 바꾸면 date 를 null 로 지운다")
            let repository = self.makeRepository()
            let start = GoogleCalendar.EventOrigin.GoogleEventTime()
                |> \.dateTime .~ "2026-08-15T10:00:00+09:00"
                |> \.timeZone .~ "Asia/Seoul"
            let end = GoogleCalendar.EventOrigin.GoogleEventTime()
                |> \.dateTime .~ "2026-08-15T11:00:00+09:00"
                |> \.timeZone .~ "Asia/Seoul"
            let params = GoogleCalendar.EventEditParams()
                |> \.start .~ start
                |> \.end .~ end

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )

            // then
            let requestedParams = try #require(self.stubRemote.didRequestedParams)
            let startJson = try #require(requestedParams["start"] as? [String: Any])
            #expect(startJson["dateTime"] as? String == "2026-08-15T10:00:00+09:00")
            #expect(startJson["date"] is NSNull)
            let endJson = try #require(requestedParams["end"] as? [String: Any])
            #expect(endJson["dateTime"] as? String == "2026-08-15T11:00:00+09:00")
            #expect(endJson["date"] is NSNull)
        }
    }

    @Test func repository_updateEvent_sendsRecurrenceArray() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_recurrence_1") {
            // given
            let expect = self.expectConfirm("반복 규칙을 실은 patch 요청")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.recurrence .~ ["RRULE:FREQ=DAILY;COUNT=3", "EXDATE;TZID=Asia/Seoul:20260101T090000"]

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )

            // then
            let requestedParams = try #require(self.stubRemote.didRequestedParams)
            let recurrence = requestedParams["recurrence"] as? [String]
            #expect(recurrence == ["RRULE:FREQ=DAILY;COUNT=3", "EXDATE;TZID=Asia/Seoul:20260101T090000"])
        }
    }

    @Test func repository_updateEvent_whenRecurrenceIsNil_omitsKey() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_recurrence_2") {
            // given
            let expect = self.expectConfirm("반복을 안 건드리면 patch body 에 recurrence 키가 없다")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.summary .~ "updated summary"

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )

            // then
            let requestedParams = try #require(self.stubRemote.didRequestedParams)
            #expect(requestedParams["recurrence"] == nil)
        }
    }

    @Test func repository_updateEvent_sendsAttendeesArray() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_attendees_1") {
            // given
            let expect = self.expectConfirm("참석자 목록을 실은 patch 요청")
            let repository = self.makeRepository()
            let attendee = GoogleCalendar.EventOrigin.Attendee()
                |> \.id .~ "attendee-id"
                |> \.email .~ "a@b.com"
                |> \.displayName .~ "A B"
                |> \.organizer .~ true
                |> \.selfValue .~ true
                |> \.resource .~ true
                |> \.optional .~ true
                |> \.responseStatus .~ "accepted"
            let params = GoogleCalendar.EventEditParams()
                |> \.attendees .~ [attendee]

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )

            // then
            let requestedParams = try #require(self.stubRemote.didRequestedParams)
            let attendeesJson = try #require(requestedParams["attendees"] as? [[String: Any]])
            let attendeeJson = try #require(attendeesJson.first)
            #expect(attendeeJson["email"] as? String == "a@b.com")
            #expect(attendeeJson["displayName"] as? String == "A B")
            #expect(attendeeJson["responseStatus"] as? String == "accepted")
            #expect(attendeeJson["optional"] as? Bool == true)
            #expect(attendeeJson["resource"] as? Bool == true)
            #expect(attendeeJson["id"] == nil)
            #expect(attendeeJson["self"] == nil)
            #expect(attendeeJson["organizer"] == nil)
        }
    }

    @Test func repository_updateEvent_whenAttendeesIsNil_omitsKey() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_attendees_2") {
            // given
            let expect = self.expectConfirm("참석자를 안 건드리면 patch body 에 attendees 키가 없다")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.summary .~ "updated summary"

            // when
            let _ = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "time_is_date", params)
            )

            // then
            let requestedParams = try #require(self.stubRemote.didRequestedParams)
            #expect(requestedParams["attendees"] == nil)
        }
    }

    @Test func repository_updateEvent_whenResponseIsSeriesMaster_doesNotCacheAsInstanceDetail() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_4") {
            // given — "전체 일정" 저장은 시리즈 마스터(recurringEventId 없음 + recurrence 있음)를 돌려준다
            let expect = self.expectConfirm("시리즈 마스터 응답은 인스턴스 캐시로 남기지 않는다")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.summary .~ "updated all"

            // when
            let updated = try await self.firstOutput(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "series1", params)
            )

            // then
            #expect(updated?.recurringEventId == nil)
            #expect(updated?.recurrence != nil)
            await #expect(throws: (any Error).self) {
                _ = try await self.cacheStorage.loadEventDetail("series1", accountId: self.testAccountId)
            }
        }
    }

    @Test func repository_removeEvent_sendsDeleteRequest() async throws {
        try await self.runTestWithOpenClose("test_google_event_remove_1") {
            // given
            let expect = self.expectConfirm("이벤트 삭제 요청")
            let repository = self.makeRepository()

            // when
            try await self.firstOutput(expect, for: repository.removeEvent("c_id", "time_is_date"))

            // then
            #expect(self.stubRemote.didRequestedMethod == .delete)
        }
    }

    @Test func repository_removeEvent_removesFromLocalCache() async throws {
        try await self.runTestWithOpenClose("test_google_event_remove_2") {
            // given
            try await self.saveCache()
            let beforeRemove = try await self.cacheStorage.loadEventDetail("time_is_date", accountId: self.testAccountId)
            #expect(beforeRemove.id == "time_is_date")

            let expect = self.expectConfirm("이벤트 삭제 후 로컬 캐시 제거")
            let repository = self.makeRepository()

            // when
            try await self.firstOutput(expect, for: repository.removeEvent("c_id", "time_is_date"))

            // then
            await #expect(throws: (any Error).self) {
                _ = try await self.cacheStorage.loadEventDetail("time_is_date", accountId: self.testAccountId)
            }
        }
    }

    @Test func repository_updateEvent_whenRemoteFails_keepsLocalCacheUntouched() async throws {
        try await self.runTestWithOpenClose("test_google_event_update_fail") {
            // given
            try await self.saveCache("fail_event")
            let repository = self.makeRepository()
            let params = GoogleCalendar.EventEditParams()
                |> \.summary .~ "updated summary"

            // when
            let expect = self.expectConfirm("이벤트 수정 실패")
            let error = try await self.failure(
                expect, for: repository.updateEvent("c_id", "Asia/Seoul", "fail_event", params)
            )

            // then
            #expect(error != nil)
            let cached = try await self.cacheStorage.loadEventDetail("fail_event", accountId: self.testAccountId)
            #expect(cached.summary == "old")
        }
    }

    @Test func repository_removeEvent_whenRemoteFails_keepsLocalCacheUntouched() async throws {
        try await self.runTestWithOpenClose("test_google_event_remove_fail") {
            // given
            try await self.saveCache("fail_event")
            let repository = self.makeRepository()

            // when
            let expect = self.expectConfirm("이벤트 삭제 실패")
            let error = try await self.failure(expect, for: repository.removeEvent("c_id", "fail_event"))

            // then
            #expect(error != nil)
            let cached = try await self.cacheStorage.loadEventDetail("fail_event", accountId: self.testAccountId)
            #expect(cached.id == "fail_event")
        }
    }

    private func assertUpdatedEventOrigin(_ origin: GoogleCalendar.EventOrigin?) {
        #expect(origin?.id == "time_is_date")
        #expect(origin?.summary == "하루죙일")
        #expect(origin?.description == "description")
        #expect(origin?.location == "Hangang Kukdong Apartments, 38-6 Toseong-ro, Songpa District, Seoul, South Korea")
        #expect(origin?.colorId == "2")
        #expect(origin?.recurringEventId == "origin")
        #expect(origin?.status == .confirmed)
    }
}

extension GoogleCalendarRepositoryImple_Tests {

    @Test func storage_whenConnectionNotAvailable_throwsError() async throws {
        // given
        let failingPool = FailingExternalCalendarSQLiteConnectionPool()
        let storage = GoogleCalendarLocalStorageImple(connectionPool: failingPool)

        // when + then
        await #expect(throws: (any Error).self) {
            _ = try await storage.loadColors(accountId: "test@google.com")
        }
    }
}


private final class StubExternalCalendarSQLiteConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {

    private let service: SQLiteService
    init(_ service: SQLiteService) { self.service = service }

    func hasConnection(serviceId: String) async -> Bool { return true }
    func connection(serviceId: String) async throws -> SQLiteService { return service }
}

private final class FailingExternalCalendarSQLiteConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {

    func hasConnection(serviceId: String) async -> Bool { return false }
    func connection(serviceId: String) async throws -> SQLiteService {
        throw RuntimeError("no connection available")
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
            ),
            .init(
                method: .get,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "private_event"),
                resultJsonString: .success(self.privateEvent)
            ),
            .init(
                method: .patch,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "time_is_date"),
                resultJsonString: .success(self.dummyNewEvent("time_is_date"))
            ),
            .init(
                method: .patch,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "series1"),
                resultJsonString: .success(self.dummyNewEvent("series1", isRepeatOrigin: true))
            ),
            .init(
                method: .delete,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "time_is_date"),
                resultJsonString: .success("")
            ),
            .init(
                method: .patch,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "fail_event"),
                resultJsonString: .failure(RuntimeError("failed"))
            ),
            .init(
                method: .delete,
                endpoint: GoogleCalendarEndpoint.event(calendarId: "c_id", eventId: "fail_event"),
                resultJsonString: .failure(RuntimeError("failed"))
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
          "attendees": [
            {
              "email": "user1@email.com",
              "organizer": true,
              "self": true,
              "responseStatus": "accepted",
              "resource": true
            }
         ],
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
    
    private var privateEvent: String {
        return """
        {
          "creator": {
            "email": "some@email.com"
          },
          "end": {
            "dateTime": "2025-01-01T21:30:00-08:00",
            "timeZone": "Asia/Seoul"
          },
          "etag": "\\"123123\\"",
          "htmlLink": "https://www.google.com",
          "iCalUID": "some@emai.com",
          "id": "private_event",
          "kind": "calendar#event",
          "start": {
            "dateTime": "2025-01-01T20:30:00-08:00",
            "timeZone": "Asia/Seoul"
          },
          "status": "confirmed",
          "updated": "2025-01-02T04:43:34.380Z",
          "visibility": "private"
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
