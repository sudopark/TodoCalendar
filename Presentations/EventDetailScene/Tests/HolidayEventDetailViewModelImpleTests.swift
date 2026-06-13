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
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene


final class HolidayEventDetailViewModelImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter = SpyRouter()
    
    private func makeViewModel() async throws -> HolidayEventDetailViewModelImple {
        let usecase = PrivateStubHolidayUsecase()
        try await usecase.prepare()
        let viewModel = HolidayEventDetailViewModelImple(
            uuid: "some",
            holidayUsecase: usecase,
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase()
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
            daysIntervalCountUsecase: StubDaysIntervalCountUsecase()
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

private final class PrivateStubHolidayUsecase: StubHolidayUsecase {
    
    override func holiday(_ uuid: String) -> AnyPublisher<Holiday?, Never> {
        let holiday = Holiday(uuid: "some", dateString: "2025-03-01", name: "삼일절")
        return Just(holiday).eraseToAnyPublisher()
    }
}

private final class SpyRouter: BaseSpyRouter, HolidayEventDetailRouting, @unchecked Sendable { }
