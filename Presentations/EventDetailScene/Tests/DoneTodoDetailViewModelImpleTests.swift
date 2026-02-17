//
//  DoneTodoDetailViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


final class DoneTodoDetailViewModelImpleTests: PublisherWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter: SpyRouter = .init()
    private let spyListener: SpyListener = .init()
    
    private func makeViewModel(
        done: DoneTodoEvent,
        detail: EventDetailData?,
        shouldLoadDoneFail: Bool = false,
        shouldLoadDetailFail: Bool = false,
        shouldFailRevert: Bool = false
    ) -> DoneTodoDetailViewModelImple {
        
        let todoUsecase = StubTodoEventUsecase()
        todoUsecase.stubDoneTodo = shouldLoadDoneFail ? nil : done
        todoUsecase.shouldFailRevert = shouldFailRevert
        
        let detailUsecase = PrivateStubEventDetailUsecase()
        detailUsecase.stubDetail = shouldLoadDetailFail ? nil : detail
        
        let tagUsecase = StubEventTagUsecase()
        let calendarUsecase = StubCalendarSettingUsecase()
        calendarUsecase.prepare()
        
        let uiSettingUsecase = StubUISettingUsecase()
        _ = uiSettingUsecase.loadSavedAppearanceSetting()
        
        let viewModel = DoneTodoDetailViewModelImple(
            uuid: done.uuid,
            todoEventUsecase: todoUsecase,
            doneDetailUsecase: detailUsecase,
            eventTagUsecase: tagUsecase,
            calendarSettingUsecase: calendarUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        return viewModel
    }
    
    private class DoneTodoDetailStateRecorder {
        
        var names: [String] = []
        var tags: [SelectedTag?] = []
        var times: [DoneAndOriginEventTimeModel] = []
        var notiOptions: [String?] = []
        var urls: [String?] = []
        var memo: [String?] = []
        var places: [SelectedPlaceModel?] = []
        
        var cancellables: Set<AnyCancellable> = []
        
        func record(_ viewModel: DoneTodoDetailViewModelImple) {
            
            viewModel.eventName
                .sink(receiveValue: { self.names.append($0) })
                .store(in: &self.cancellables)
            
            viewModel.eventTag
                .sink(receiveValue: { self.tags.append($0) })
                .store(in: &self.cancellables)
            
            viewModel.timeModel
                .sink(receiveValue: { self.times.append($0) })
                .store(in: &self.cancellables)
            
            viewModel.notificationTimeText
                .sink(receiveValue: { self.notiOptions.append($0) })
                .store(in: &self.cancellables)
            
            viewModel.url
                .sink(receiveValue: { self.urls.append($0) })
                .store(in: &self.cancellables)
            
            viewModel.memo
                .sink(receiveValue: { self.memo.append($0) })
                .store(in: &self.cancellables)
            
            viewModel.placeModel
                .sink(receiveValue: { self.places.append($0) })
                .store(in: &self.cancellables)
        }
    }
}

extension DoneTodoDetailViewModelImpleTests {
    
    var dummyDoneTodo: DoneTodoEvent {
        return DoneTodoEvent(
            uuid: "done_id",
            name: "name",
            originEventId: "origin",
            doneTime: Date(timeIntervalSince1970: 0)
        )
        |> \.eventTagId .~ .custom("some")
        |> \.eventTime .~ .at(10)
        |> \.notificationOptions .~ [.allDay12AM]
    }
    
    var dummyDetail: EventDetailData {
        return .init("done_id")
            |> \.place .~ Place("place")
            |> \.url .~ "url"
            |> \.memo .~ "memo"
    }
    
    // done todo detail without detail
    @Test func viewModel_doneTodoWithoutDetail() async throws {
        // given
        let viewModel = self.makeViewModel(
            done: self.dummyDoneTodo, detail: nil
        )
        let recorder = DoneTodoDetailStateRecorder()
        recorder.record(viewModel)
        
        // when
        viewModel.prepare()
        try await Task.sleep(for: .milliseconds(10))
        
        // then
        #expect(recorder.names == ["name"])
        #expect(recorder.tags == [.init(.custom("some"), "some", "0x000000")])
        #expect(recorder.times.map { $0.doneTime } == ["01/01/1970 9:00 AM"])
        #expect(recorder.times.map { $0.eventTime != nil } == [true])
        #expect(recorder.notiOptions == ["At noon that day"])
        #expect(recorder.urls == [])
        #expect(recorder.memo == [])
        #expect(recorder.places == [])
    }
    
    // done todo detail with detail
    @Test func viewModel_doneTodoWithDetail() async throws {
        // given
        let viewModel = self.makeViewModel(
            done: self.dummyDoneTodo, detail: self.dummyDetail
        )
        let recorder = DoneTodoDetailStateRecorder()
        recorder.record(viewModel)
        
        // when
        viewModel.prepare()
        try await Task.sleep(for: .milliseconds(10))
        
        // then
        #expect(recorder.names == ["name"])
        #expect(recorder.tags == [.init(.custom("some"), "some", "0x000000")])
        #expect(recorder.times.map { $0.doneTime } == ["01/01/1970 9:00 AM"])
        #expect(recorder.times.map { $0.eventTime != nil } == [true])
        #expect(recorder.notiOptions == ["At noon that day"])
        #expect(recorder.urls == ["url"])
        #expect(recorder.memo == ["memo"])
        #expect(recorder.places.map { $0 != nil } == [true])
    }
    
    // done todo detail load done todo fail -> notify failed
    @Test func viewModel_whenLoadDoneTodoFail_showError() {
        // given
        let viewModel = self.makeViewModel(done: self.dummyDoneTodo, detail: nil, shouldLoadDoneFail: true)
        
        // when
        viewModel.prepare()
        
        // then
        #expect(self.spyRouter.didShowError != nil)
    }
    
    // done todo detail load detail fail -> ignore
    @Test func viewModel_whenLoadEventDetailFail_ignore() async throws {
        // given
        let viewModel = self.makeViewModel(
            done: self.dummyDoneTodo, detail: self.dummyDetail,
            shouldLoadDetailFail: true
        )
        let recorder = DoneTodoDetailStateRecorder()
        recorder.record(viewModel)
        
        // when
        viewModel.prepare()
        try await Task.sleep(for: .milliseconds(10))
        
        // then
        #expect(recorder.names == ["name"])
        #expect(recorder.tags == [.init(.custom("some"), "some", "0x000000")])
        #expect(recorder.times.map { $0.doneTime } == ["01/01/1970 9:00 AM"])
        #expect(recorder.times.map { $0.eventTime != nil } == [true])
        #expect(recorder.notiOptions == ["At noon that day"])
        #expect(recorder.urls == [])
        #expect(recorder.memo == [])
        #expect(recorder.places == [])
    }
    
    // done todo detail -> revert -> notify
    @Test func viewModel_whenAfterRevertTodo_notify() async throws {
        // given
        let expect = expectConfirm("done todo detail -> revert -> notify")
        expect.count = 3; expect.timeout = .milliseconds(100)
        let viewModel = self.makeViewModel(done: self.dummyDoneTodo, detail: nil)
        viewModel.prepare()
        
        // when
        let isRevertings = try await self.outputs(expect, for: viewModel.isReverting) {
            viewModel.revert()
            
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // then
        #expect(isRevertings == [false, true, false])
        #expect(self.spyRouter.didClosed == true)
        #expect(self.spyListener.didDoneTodoNotified != nil)
    }
    
    @Test func viewModel_whenRevertTodoFail_showError() async throws {
        // given
        let expect = expectConfirm("done todo detail -> revert fail -> notify")
        expect.count = 3; expect.timeout = .milliseconds(100)
        let viewModel = self.makeViewModel(done: self.dummyDoneTodo, detail: nil, shouldFailRevert: true)
        viewModel.prepare()
        
        // when
        let isRevertings = try await self.outputs(expect, for: viewModel.isReverting) {
            viewModel.revert()
            
            try await Task.sleep(for: .milliseconds(10))
        }
        
        // then
        #expect(isRevertings == [false, true, false])
        #expect(self.spyRouter.didShowError != nil)
    }
}

private final class PrivateStubEventDetailUsecase: StubEventDetailDataUsecase, @unchecked Sendable {
    
    override func loadDetail(_ id: String) -> AnyPublisher<EventDetailData, any Error> {
        guard let detail = self.stubDetail
        else {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        }
        return Just(detail).mapNever().eraseToAnyPublisher()
    }
}

private final class SpyRouter: BaseSpyRouter, DoneTodoDetailRouting, @unchecked Sendable {
    
}

private final class SpyListener: DoneTodoDetailSceneListener {
    
    var didDoneTodoNotified: String?
    func doneTodoDetail(revert doneTodoId: String, to todo: TodoEvent) {
        self.didDoneTodoNotified = doneTodoId
    }
}
