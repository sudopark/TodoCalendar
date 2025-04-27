//
//  EventTagListViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 2023/09/24.
//

import XCTest
import Combine
import Domain
import Scenes
import Extensions
import TestDoubles
import UnitTestHelpKit

@testable import SettingScene


class EventTagListViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel(shouldLoadFail: Bool = false) -> EventTagListViewModelImple {
        let usecase = StubEventTagUsecase()
        if shouldLoadFail {
            usecase.allTagsLoadResult = .failure(RuntimeError("failed"))
        } else {
            let tags = (0..<20).map {
                return CustomEventTag(uuid: "id:\($0)", name: "n:\($0)", colorHex: "some")
            }
            usecase.allTagsLoadResult = .success(tags)
        }
        let googleUsecae = StubGoogleCalendarUsecase()
        let viewModel = EventTagListViewModelImple(
            tagUsecase: usecase,
            googleCalendarUsecase: googleUsecae
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension EventTagListViewModelImpleTests {
    
    func testViewModel_provideTags() {
        // given
        let expect = expectation(description: "tag 리스트 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let cells = self.waitFirstOutput(expect, for: viewModel.cellViewModels) {
            viewModel.reload()
        }
        
        // then
        XCTAssertEqual(cells?.count, 22)
        XCTAssertEqual(cells?[safe: 0]?.id, .default)
        XCTAssertEqual(cells?[safe: 1]?.id, .holiday)
    }
    
    func testViewModel_whenLoadAllTagsFail_showError() {
        // given
        let expect = expectation(description: "tag 리스트 조회 실패시에 에러 알림")
        let viewModel = self.makeViewModel(shouldLoadFail: true)
        self.spyRouter.didShowErrorCallback = { _ in
            expect.fulfill()
        }
        
        // when
        viewModel.reload()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_provideExternalCalendarTags() {
        // given
        FeatureFlag.enable(.googleCalendar)
        let expect = expectation(description: "외부 캘린더 목록 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let sections = self.waitFirstOutput(expect, for: viewModel.externalCalendarSections) {
            viewModel.reload()
        }
        
        // then
        XCTAssertEqual(sections?.count, 1)
        let first = sections?.first
        XCTAssertEqual(first?.serviceId, GoogleCalendarService.id)
        XCTAssertEqual(first?.cellViewModels.count, 10)
        FeatureFlag.disable(.googleCalendar)
    }
    
    private func makeViewModelWithInitialListLoaded() -> EventTagListViewModelImple {
        // given
        let expect = expectation(description: "wait initial list")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.cellViewModels) {
            viewModel.reload()
        }
        
        // then
        return viewModel
    }
    
    func testViewModel_whenToggleTagIsOn_updateList() {
        // given
        let expect = expectation(description: "tag 활성화 여부 업데이트시에 리스트 업데이트")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.toggleIsOn(.custom("id:3"))
            viewModel.toggleIsOn(.custom("id:4"))
            viewModel.toggleIsOn(.custom("id:3"))
        }
        
        // then
        let offTagIds = cvmLists.map { cs in cs.filter { !$0.isOn }.map { $0.id} }
        XCTAssertEqual(offTagIds, [
            [],
            [.custom("id:3")],
            [.custom("id:3"), .custom("id:4")],
            [.custom("id:4")]
        ])
    }
    
    private func makeViewModelWithInitialExternalCalendarLoaded() -> EventTagListViewModelImple {
        // given
        let expect = expectation(description: "wait initial list")
        expect.assertForOverFulfill = false
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.externalCalendarSections) {
            viewModel.reload()
        }
        
        // then
        return viewModel
    }
    
    func testViewModel_whenToogleExternalCalendarTag_updateList() {
        // given
        FeatureFlag.enable(.googleCalendar)
        let viewModel = self.makeViewModelWithInitialExternalCalendarLoaded()
        let expect = expectation(description: "외부 캘린더 tag 활성화 여부 업데이트시에 리스트 업데이트")
        expect.expectedFulfillmentCount = 4
        
        // when
        let sectionLists = self.waitOutputs(expect, for: viewModel.externalCalendarSections) {
            viewModel.toggleIsOn(
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "g:2")
            )
            viewModel.toggleIsOn(
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "g:3")
            )
            viewModel.toggleIsOn(
                .externalCalendar(serviceId: GoogleCalendarService.id, id: "g:2")
            )
        }
        
        // then
        let offTagIds = sectionLists
            .map { $0.first?.cellViewModels }
            .map { cs in cs?.filter { !$0.isOn } }
            .map { cs in cs?.map { $0.id }}
        XCTAssertEqual(offTagIds, [
            [],
            [.externalCalendar(serviceId: GoogleCalendarService.id, id: "g:2")],
            [.externalCalendar(serviceId: GoogleCalendarService.id, id: "g:2"), .externalCalendar(serviceId: GoogleCalendarService.id, id: "g:3")],
            [.externalCalendar(serviceId: GoogleCalendarService.id, id: "g:3")]
        ])
        FeatureFlag.disable(.googleCalendar)
    }
}


// MARK: - make, edit, delete tag

extension EventTagListViewModelImpleTests {
    
    func testViewModel_makeNewTag() {
        // given
        let expect = expectation(description: "tag 생성 이후 리스트 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.addNewTag()
        }
        
        // then
        let tagCounts = cvmLists.map { $0.count }
        let hasNewTags = cvmLists.map { $0.contains(where: { $0.name == "new" }) }
        XCTAssertEqual(self.spyRouter.didRouteToAddNewTag, true)
        XCTAssertEqual(tagCounts, [22, 23])
        XCTAssertEqual(hasNewTags, [false, true])
    }
    
    func testViewModel_editTag() {
        // given
        let expect = expectation(description: "tag 수정 이후 리스트 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            viewModel.showTagDetail(.custom("id:4"))
        }
        
        // then
        let tagCounts = cvmLists.map { $0.count }
        let tag4s = cvmLists.map { cs in cs.first(where: { $0.id == .custom("id:4") }) }
        XCTAssertEqual(self.spyRouter.didRouteToEditTag, true)
        XCTAssertEqual(tagCounts, [22, 22])
        XCTAssertEqual(tag4s.map { $0?.name }, ["n:4", "edited name"])
        XCTAssertEqual(tag4s.map { $0?.colorHex }, [
            "some", "edited color hex"
        ])
    }
    
    func testViewModel_deleteTag() {
        // given
        let expect = expectation(description: "tag 삭제")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithInitialListLoaded()
        
        // when
        let cvmLists = self.waitOutputs(expect, for: viewModel.cellViewModels) {
            self.spyRouter.shouldDeleteTagWhenEdit = true
            viewModel.showTagDetail(.custom("id:4"))
        }
        
        // then
        let tagCounts = cvmLists.map { $0.count }
        let hasTag4s = cvmLists.map { cs in cs.contains(where: { $0.id == .custom("id:4") }) }
        XCTAssertEqual(self.spyRouter.didRouteToEditTag, true)
        XCTAssertEqual(tagCounts, [22, 21])
        XCTAssertEqual(hasTag4s, [true, false])
    }
    
    func testViewModel_whenIntegrateExternalCalendar_routeToEventSetting() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.integrateCalendar(serviceId: GoogleCalendarService.id)
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToEventSetting, true)
    }
}

extension EventTagListViewModelImpleTests {

    
    private class SpyRouter: BaseSpyRouter, EventTagListRouting, @unchecked Sendable
    {
        
        var didRouteToAddNewTag: Bool?
        func routeToAddNewTag(listener: EventTagDetailSceneListener) {
            self.didRouteToAddNewTag = true
            let newTag = CustomEventTag(name: "new", colorHex: "some")
            listener.eventTag(created: newTag)
        }
        
        var shouldDeleteTagWhenEdit: Bool = false
        var didRouteToEditTag: Bool?
        func routeToEditTag(
            _ tagInfo: OriginalTagInfo,
            listener: EventTagDetailSceneListener
        ) {
            self.didRouteToEditTag = true
            if shouldDeleteTagWhenEdit {
                listener.eventTag(deleted: tagInfo.id)
            } else {
                let newTag = CustomEventTag(
                    uuid: tagInfo.id.customTagId ?? "",
                    name: "edited name",
                    colorHex: "edited color hex"
                )
                listener.eventTag(updated: newTag)
            }
        }
        
        var didRouteToEventSetting: Bool?
        func routeToEventSetting() {
            self.didRouteToEventSetting = true
        }
    }
}
