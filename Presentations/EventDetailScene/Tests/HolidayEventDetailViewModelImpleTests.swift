//
//  HolidayEventDetailViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 10/12/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
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


final class HolidayEventDetailViewModelImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter = SpyRouter()
    private let stubLiveActivityUsecase = StubEventLiveActivityUsecase()
    
    private func makeViewModel(
        registeredLiveActivityTarget: LiveActivityTarget? = nil,
        liveActivityStartError: (any Error)? = nil
    ) async throws -> HolidayEventDetailViewModelImple {
        let usecase = PrivateStubHolidayUsecase()
        try await usecase.prepare()
        self.stubLiveActivityUsecase.registeredTargetSubject.send(registeredLiveActivityTarget)
        self.stubLiveActivityUsecase.stubStartError = liveActivityStartError
        let viewModel = HolidayEventDetailViewModelImple(
            uuid: "some",
            holidayUsecase: usecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase(),
            eventLiveActivityUsecase: self.stubLiveActivityUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension HolidayEventDetailViewModelImpleTests {
    
    @Test func viewModel_provideName() async throws {
        // given
        let expect = expectConfirm("이름정보 제공")
        let viewModel = try await self.makeViewModel()
        
        // when
        let name = try await self.firstOutput(expect, for: viewModel.holidayName) {
            viewModel.refresh()
        }
        
        // then
        #expect(name == "삼일절")
    }
    
    @Test func viewModel_provideDateText() async throws {
        // given
        let expect = expectConfirm("날짜 정보 제공")
        let viewModel = try await self.makeViewModel()
        
        // when
        let dateText = try await self.firstOutput(expect, for: viewModel.dateText) {
            viewModel.refresh()
        }
        
        // then
        #expect(dateText == "03/01/2025 (Sat)")
    }
    
    @Test func viewModel_provideDDayText() async throws {
        // given
        let expect = expectConfirm("d-day 정보 제공")
        expect.count = 3
        let viewModel = try await self.makeViewModel()
        
        // when
        let days = try await self.outputs(expect, for: viewModel.ddayText) {
            viewModel.refresh()
        }
        
        // then
        #expect(days == [
            "D+4", "D-Day", "D-4"
        ])
    }
    
    @Test func viewModel_provideCountryInfo() async throws {
        // given
        let expect = expectConfirm("국가 정보 제공")
        let viewModel = try await self.makeViewModel()
        
        // when
        let model = try await self.firstOutput(expect, for: viewModel.countryModel) {
            viewModel.refresh()
        }
        
        // then
        #expect(
            model == .init(thumbnailUrl: "https://flagcdn.com/w160/kr.jpg", name: "Korea")
        )
    }
}

// MARK: - test hide holiday

extension HolidayEventDetailViewModelImpleTests {

    private func makeViewModelWithUsecase() async throws -> (HolidayEventDetailViewModelImple, PrivateStubHolidayUsecase) {
        let usecase = PrivateStubHolidayUsecase()
        try await usecase.prepare()
        let viewModel = HolidayEventDetailViewModelImple(
            uuid: "some",
            holidayUsecase: usecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase(),
            eventLiveActivityUsecase: self.stubLiveActivityUsecase
        )
        viewModel.router = self.spyRouter
        return (viewModel, usecase)
    }

    // 숨기기 확인 시 현재 공휴일 이름으로 숨김 요청하고 화면을 닫음
    @Test func viewModel_whenHideHolidayConfirmed_requestHideAndCloseScene() async throws {
        // given
        let (viewModel, usecase) = try await self.makeViewModelWithUsecase()
        viewModel.refresh()

        // when: 닫힘 콜백으로 비동기 숨김 완료를 결정적으로 대기
        await withCheckedContinuation { continuation in
            self.spyRouter.didCloseCallback = { continuation.resume() }
            viewModel.hideHoliday()
        }

        // then
        #expect(self.spyRouter.didShowConfirmWith != nil)
        #expect(self.spyRouter.didClosed == true)
        #expect(usecase.hiddenHolidayNamesSubject.value == ["삼일절"])
    }

    // 숨기기 취소 시 숨김 요청도 닫기도 하지 않음
    @Test func viewModel_whenHideHolidayCanceled_doNothing() async throws {
        // given
        let (viewModel, usecase) = try await self.makeViewModelWithUsecase()
        self.spyRouter.shouldConfirmNotCancel = false
        viewModel.refresh()

        // when
        viewModel.hideHoliday()

        // then
        #expect(self.spyRouter.didShowConfirmWith != nil)
        #expect(self.spyRouter.didClosed != true)
        #expect(usecase.hiddenHolidayNamesSubject.value.isEmpty)
    }
}


// MARK: - 라이브액티비티 등록·해제

extension HolidayEventDetailViewModelImpleTests {

    @Test func viewModel_whenHolidayLoaded_provideLiveActivityAction() async throws {
        // given
        let expect = expectConfirm("공휴일이 로드되면 등록 항목 노출")
        expect.count = 2
        let viewModel = try await self.makeViewModel()

        // when
        let models = try await self.outputs(expect, for: viewModel.liveActivityActionModel) {
            viewModel.refresh()
        }

        // then
        #expect(models == [nil, LiveActivityActionModel(isRegistered: false)])
    }

    @Test func viewModel_whenHolidayLiveActivityRegistered_provideUnregisterAction() async throws {
        // given
        let expect = expectConfirm("등록된 공휴일은 해제 항목으로 노출")
        expect.count = 2
        let viewModel = try await self.makeViewModel(
            registeredLiveActivityTarget: .holiday(uuid: "some", dateString: "2025-03-01")
        )

        // when
        let models = try await self.outputs(expect, for: viewModel.liveActivityActionModel) {
            viewModel.refresh()
        }

        // then
        #expect(models == [nil, LiveActivityActionModel(isRegistered: true)])
    }

    @Test func viewModel_whenToggleLiveActivity_startActivityWithHolidayTarget() async throws {
        // given
        let viewModel = try await self.makeViewModel()
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(100))

        // when
        viewModel.toggleLiveActivity(isRegistered: false)
        try await Task.sleep(for: .milliseconds(100))

        // then
        #expect(
            self.stubLiveActivityUsecase.didStartTarget
            == .holiday(uuid: "some", dateString: "2025-03-01")
        )
        #expect(self.stubLiveActivityUsecase.didStopActivity == false)
    }

    @Test func viewModel_whenToggleRegisteredLiveActivity_stopActivity() async throws {
        // given
        let viewModel = try await self.makeViewModel(
            registeredLiveActivityTarget: .holiday(uuid: "some", dateString: "2025-03-01")
        )
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(100))

        // when
        viewModel.toggleLiveActivity(isRegistered: true)
        try await Task.sleep(for: .milliseconds(100))

        // then
        #expect(self.stubLiveActivityUsecase.didStopActivity == true)
        #expect(self.stubLiveActivityUsecase.didStartTarget == nil)
    }

    @Test func viewModel_whenStartLiveActivityFail_showUnavailableMessage() async throws {
        // given
        let viewModel = try await self.makeViewModel(
            liveActivityStartError: EventLiveActivityStartFailReason.tooFarFuture
        )
        viewModel.refresh()
        try await Task.sleep(for: .milliseconds(100))

        // when
        viewModel.toggleLiveActivity(isRegistered: false)
        try await Task.sleep(for: .milliseconds(100))

        // then
        #expect(
            self.spyRouter.didShowConfirmWith?.message
            == "calendar::event::more_action:live_activity:unavail::too_far_future".localized()
        )
        #expect(self.spyRouter.didShowConfirmWith?.withCancel == false)
        #expect(self.spyRouter.didShowError == nil)
    }
}


private final class PrivateStubHolidayUsecase: StubHolidayUsecase {
    
    override func holiday(_ uuid: String) -> AnyPublisher<Holiday?, Never> {
        let holiday = Holiday(uuid: "some", dateString: "2025-03-01", name: "삼일절")
        return Just(holiday).eraseToAnyPublisher()
    }
}

private final class SpyRouter: BaseSpyRouter, HolidayEventDetailRouting, @unchecked Sendable { }
