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
        let viewModel = HolidayEventDetailViewModelImple(uuid: "some", holidayUsecase: usecase)
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

private final class PrivateStubHolidayUsecase: StubHolidayUsecase {
    
    override func holiday(_ uuid: String) -> AnyPublisher<Holiday?, Never> {
        let holiday = Holiday(uuid: "some", dateString: "2025-03-01", name: "삼일절")
        return Just(holiday).eraseToAnyPublisher()
    }
}

private final class SpyRouter: BaseSpyRouter, HolidayEventDetailRouting, @unchecked Sendable { }
