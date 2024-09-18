//
//  EventTagUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/05/27.
//

import XCTest
import Combine
import Prelude
import Optics
import Extensions
import AsyncFlatMap
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class EventTagUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var stubRepository: StubEventTagRepository!
    private var sharedDataStore: SharedDataStore!
    private var serialQueue: DispatchQueue!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.stubRepository = .init()
        self.sharedDataStore = .init()
        self.serialQueue = DispatchQueue.main
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.stubRepository = nil
        self.sharedDataStore = nil
        self.serialQueue = nil
    }
    
    private func makeUsecase() -> EventTagUsecaseImple {
        self.stubRepository.stubLatestUsecaseTag = .init(uuid: "latest", name: "latest", colorHex: "some")
        return EventTagUsecaseImple(
            tagRepository: self.stubRepository,
            sharedDataStore: self.sharedDataStore,
            refreshBindingQueue: self.serialQueue
        )
    }
    
    private func stubMakeFail() {
        self.stubRepository.makeFailError = RuntimeError("duplicate name")
    }
    
    private func stubUpdateFail() {
        self.stubRepository.updateFailError = RuntimeError("duplicate name")
    }
}


extension EventTagUsecaseImpleTests {
    
    // make new
    func testUsecase_makeNewTag() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EventTagMakeParams(name: "new", colorHex: "hex")
        let new = try? await usecase.makeNewTag(params)
        
        // then
        XCTAssertEqual(new?.name, "new")
        XCTAssertEqual(new?.colorHex, "hex")
    }
    
    // make new error
    func testUsecase_makeNewTagFail() async {
        // given
        let usecase = self.makeUsecase()
        self.stubMakeFail()
        
        // when
        let params = EventTagMakeParams(name: "new", colorHex: "hex")
        let new = try? await usecase.makeNewTag(params)
        
        // then
        XCTAssertNil(new)
    }
    
    // update new
    func testUsecase_updateTag() async {
        // given
        let usecase = self.makeUsecase()
        let makeParams = EventTagMakeParams(name: "origin", colorHex: "hex")
        let origin = try? await usecase.makeNewTag(makeParams)
        
        // when
        let updateParams = EventTagEditParams(name: "new name", colorHex: "new hex")
        let new = try? await usecase.editTag(origin?.uuid ?? "", updateParams)
        
        // then
        XCTAssertEqual(new?.uuid, origin?.uuid)
        XCTAssertEqual(new?.name, "new name")
        XCTAssertEqual(new?.colorHex, "new hex")
    }
    
    // update new error
    func testUsecase_updateTagFail() async {
        // given
        let usecase = self.makeUsecase()
        self.stubUpdateFail()
        let makeParams = EventTagMakeParams(name: "origin", colorHex: "hex")
        let origin = try? await usecase.makeNewTag(makeParams)
        
        // when
        let updateParams = EventTagEditParams(name: "new name", colorHex: "new hex")
        let new = try? await usecase.editTag(origin?.uuid ?? "", updateParams)
        
        // then
        XCTAssertNil(new)
    }
    
    private func makeUsecaseWithTagAndOffed() -> EventTagUsecaseImple {
        let tags: [EventTag] = (0..<10).map {
            EventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "some")
        }
        self.sharedDataStore.put([String: EventTag].self, key: ShareDataKeys.tags.rawValue, tags.asDictionary { $0.uuid })
        self.sharedDataStore.put(Set<AllEventTagId>.self, key: ShareDataKeys.offEventTagSet.rawValue, [
            .custom("id:3"), .custom("id:4")
        ])
        return self.makeUsecase()
    }
    
    // delete
    func testUsecase_deleteTag() async {
        // given
        let usecase = self.makeUsecaseWithTagAndOffed()
        
        // when
        let void: Void? = try? await usecase.deleteTag("id:4")
        
        // then
        XCTAssertNotNil(void)
    }
    
    // delete -> remove from shared and off ids
    func testUsecase_whenDeleteTag_updateSharedTags() {
        // given
        let expect = expectation(description: "tag 삭제 이후 공유중인 이벤트 목록과 off id 에서 제외")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecaseWithTagAndOffed()
        
        // when
        let ids = (0..<10).map { "id:\($0)" }
        let tagSource = usecase.eventTags(ids)
        let offIdSource = usecase.offEventTagIdsOnCalendar()
        let source = Publishers.Zip(tagSource, offIdSource)
        let pairs = self.waitOutputs(expect, for: source) {
            Task {
                try await usecase.deleteTag("id:4")
            }
        }
        
        // then
        XCTAssertEqual(pairs.map { $0.0.keys }.map { $0.sorted() }, [
            Array(0..<10).map { "id:\($0)" },
            Array(0..<10).filter { $0 != 4 }.map { "id:\($0)" }
        ])
        XCTAssertEqual(pairs.map { $0.1 }, [
            [.custom("id:3"), .custom("id:4")], [.custom("id:3")]
        ])
    }
}

extension EventTagUsecaseImpleTests {
    
    // load tags in ids
    func testUsecase_loadEventTagsByIds() {
        // given
        let expect = expectation(description: "ids에 해당하는 event tag 조회")
        expect.expectedFulfillmentCount = 2
        let usecase = self.makeUsecase()
        
        // when
        let ids = (0..<10).map { "id:\($0)"}
        let tagSource = usecase.eventTags(ids)
        let tagMaps = self.waitOutputs(expect, for: tagSource) {
            usecase.refreshTags(ids)
        }
        
        // then
        let tagMapKeys = tagMaps.map { $0.keys.map { $0 }.sorted() }
        XCTAssertEqual(tagMapKeys, [
            [],
            ids
        ])
    }
    
    func testUsecase_loadSingleEventTag() {
        // given
        let expect = expectation(description: "id에 해당하는 event tag 조회")
        let usecase = self.makeUsecase()
        
        // when
        let tagSource = usecase.eventTag(id: "some")
        let tag = self.waitFirstOutput(expect, for: tagSource) {
            usecase.refreshTags(["some"])
        }
        
        // then
        XCTAssertEqual(tag?.uuid, "some")
    }
    
    private func stubMakeTag(_ usecase: any EventTagUsecase) -> EventTag {
        let expect = expectation(description: "tag 생성 조회")
        
        let making: AsyncFlatMapPublisher<Void, Error, EventTag> = Publishers.create {
            try await usecase.makeNewTag(.init(name: "origin", colorHex: "hex"))
        }
        
        let new = self.waitFirstOutput(expect, for: making)
        return new!
    }
    
    // load tags in ids + update one
    func testUsecase_whenAfterUpdate_updateTagsInIds() {
        // given
        let usecase = self.makeUsecase()
        let origin = self.stubMakeTag(usecase)
        let expect = expectation(description: "id에 해당하는 tag 업데이트시 조회중인 tag 업데이트")
        expect.expectedFulfillmentCount = 2
        
        // when
        let ids = [origin.uuid]
        let tagSource = usecase.eventTags(ids)
        let tagMaps = self.waitOutputs(expect, for: tagSource) {
            Task {
                let params = EventTagEditParams(name: "new name", colorHex: "hex")
                _ = try await usecase.editTag(origin.uuid, params)
            }
        }
        
        // then
        let loadedOrigin = tagMaps.first?[origin.uuid]
        let loadedUpdated = tagMaps.last?[origin.uuid]
        XCTAssertEqual(tagMaps.count, 2)
        XCTAssertEqual(loadedOrigin?.name, "origin")
        XCTAssertEqual(loadedUpdated?.name, "new name")
    }
}


extension EventTagUsecaseImpleTests {
    
    // 처음 todo1(tag-t1), todo2(no tag), todo3(tag-t3)
    //  schedule1(no tag), schedule2(tag-s2) 있음
    // 인 상태에서 구독은 tag-t1, tag-t3, tag-s2, tag-t2, tag-s3 할꺼고
    
    // 이후에 순차적으로
    //  todo2 -> tag-t2 추가
    //  schedule3(tag-s3) 추가
    //  todo3 삭제 할것임 -> 변경 없음
    // todo1의 tagId -> tag-t1-new 로 바꿀거임
    
    // 결과값 1st) tag-t1, tag-t3, tag-s2
    // 2nd) tag-t1, tag-t3, tag-s2, tag-t2
    // 3rd) tag-t1, tag-t3, tag-s2, tag-t2, tag-s3
    // 4th) tag-t1, tag-t3, tag-s2, tag-t2, tag-s3, tag-t1-new
    
    private func makeUsecaseWithStubEvents() -> EventTagUsecaseImple {
        let todos: [String: TodoEvent] = [
            "todo1": TodoEvent(uuid: "todo1", name: "todo1") |> \.eventTagId .~ .custom("tag-t1"),
            "todo2": TodoEvent(uuid: "todo2", name: "todo2"),
            "todo3": TodoEvent(uuid: "todo3", name: "todo3") |> \.eventTagId .~ .custom("tag-t3")
        ]
        self.sharedDataStore.put([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue, todos)
        
        let schedules: [ScheduleEvent] = [
            ScheduleEvent(uuid: "sc1", name: "sc1", time: .at(0)),
            ScheduleEvent(uuid: "sc2", name: "sc2", time: .at(0)) |> \.eventTagId .~ .custom("tag-s2")
        ]
        let scheduleContainer = schedules.reduce(MemorizedScheduleEventsContainer()) { $0.append($1) }
        self.sharedDataStore.put(MemorizedScheduleEventsContainer.self, key: ShareDataKeys.schedules.rawValue, scheduleContainer)
        self.stubRepository.allTagsStubbing = [
            .init(uuid: "tag-t1", name: "t1", colorHex: "some"),
            .init(uuid: "tag-t3", name: "t2", colorHex: "some"),
            .init(uuid: "tag-s2", name: "s2", colorHex: "some")
        ]
        return makeUsecase()
    }
    
    private var allTagIds: [String] {
        return ["tag-t1", "tag-t3", "tag-s2", "tag-t2", "tag-s3", "tag-t1-new"]
    }
    
    private func addTagT2ToTodo2() {
        let newTodo2 = TodoEvent(uuid: "todo2", name: "todo2") |> \.eventTagId .~ .custom("tag-t2")
        self.sharedDataStore.update([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue) {
            ($0 ?? [:]) |> key(newTodo2.uuid) .~ newTodo2
        }
    }
    
    private func addSchedule3WithTagS3() {
        let schedule3 = ScheduleEvent(uuid: "sc3", name: "sc3", time: .at(0)) |> \.eventTagId .~ .custom("tag-s3")
        self.sharedDataStore.update(MemorizedScheduleEventsContainer.self, key: ShareDataKeys.schedules.rawValue) {
            ($0 ?? .init()).append(schedule3)
        }
    }
    
    private func removeTodo3() {
        self.sharedDataStore.update([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue) {
            ($0 ?? [:]) |> key("todo3") .~ nil
        }
    }
    
    private func updateTagT1() {
        let newTodo1 = TodoEvent(uuid: "todo1", name: "todo1") |> \.eventTagId .~ .custom("tag-t1-new")
        self.sharedDataStore.update([String: TodoEvent].self, key: ShareDataKeys.todos.rawValue) {
            ($0 ?? [:]) |> key(newTodo1.uuid) .~ newTodo1
        }
    }
    
    func testUsecase_whenPrepare_bindRefreshRequireTagInfos() {
        // given
        let expect = expectation(description: "필요한 tag 정보 refresh binding")
        expect.expectedFulfillmentCount = 4
        let usecase = self.makeUsecaseWithStubEvents()
        usecase.prepare()
        
        // when
        let tagSource = usecase.eventTags(self.allTagIds).drop(while: { $0.isEmpty })
        let tagMaps = self.waitOutputs(expect, for: tagSource, timeout: 0.1) {
            self.serialQueue.asyncAfter(deadline: .now() + 0.01) {
                self.addTagT2ToTodo2()
                self.addSchedule3WithTagS3()
                self.removeTodo3()
                self.updateTagT1()
            }
        }
        
        // then
        let tagIdSets = tagMaps.map { mp in Set(mp.keys) }
        XCTAssertEqual(tagIdSets, [
            ["tag-t1", "tag-t3", "tag-s2"],
            ["tag-t1", "tag-t3", "tag-s2", "tag-t2"],
            ["tag-t1", "tag-t3", "tag-s2", "tag-t2", "tag-s3"],
            ["tag-t1", "tag-t3", "tag-s2", "tag-t2", "tag-s3", "tag-t1-new"]
        ])
    }
    
    func testUsecase_loadAllTags() {
        // given
        let expect = expectation(description: "load all tags")
        let usecase = self.makeUsecaseWithStubEvents()
        
        // when
        let tags = self.waitFirstOutput(expect, for: usecase.loadAllEventTags())
        
        // then
        let ids = tags?.map { $0.uuid }
        XCTAssertEqual(ids, [
            "tag-t1", "tag-t3", "tag-s2"
        ])
    }
}


extension EventTagUsecaseImpleTests {
    
    func testUsecase_toggleIsOffTagIds() {
        // given
        let expect = expectation(description: "필터링된 이벤트 아이디 set 제공")
        expect.expectedFulfillmentCount = 5
        let usecase = self.makeUsecase()
        
        // when
        let offIds = self.waitOutputs(expect, for: usecase.offEventTagIdsOnCalendar()) {
            usecase.toggleEventTagIsOnCalendar(.custom("id1"))
            usecase.toggleEventTagIsOnCalendar(.custom("id2"))
            usecase.toggleEventTagIsOnCalendar(.custom("id1"))
            usecase.toggleEventTagIsOnCalendar(.holiday)
        }
        
        // then
        XCTAssertEqual(offIds, [
            [],
            [.custom("id1")],
            [.custom("id1"), .custom("id2")],
            [.custom("id2")],
            [.custom("id2"), .holiday]
        ])
    }
}
