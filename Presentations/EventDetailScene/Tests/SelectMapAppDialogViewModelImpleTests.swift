//
//  SelectMapAppDialogViewModelImpleTests.swift
//  EventDetailSceneTests
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import EventDetailScene

class SelectMapAppDialogViewModelImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private let spyEventSettingUsecase = StubEventSettingUsecase()
    private let spyRouter = SpyRouter()
    
    private func makeViewModel() -> SelectMapAppDialogViewModelImple {
        let viewModel = SelectMapAppDialogViewModelImple(
            query: "query", supportMapApps: [.apple, .google],
            eventSettingUsecase: self.spyEventSettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension SelectMapAppDialogViewModelImpleTests {
    
    // open map
    @Test func viewModel_openMap() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.selectMap(.apple)
        
        // then
        #expect(self.spyRouter.didOpenMap == true)
        #expect(self.spyRouter.didClosed == true)
    }
    
    // open map with always select option + update eventSetting
    @Test func viewModel_whenOpenAppWithAlwaysSelectThisMapOption_updateEventSetting() async throws {
        // given
        let expect = expectConfirm("항상 이 앱과 함께 지도 열기 옵션 on된 상태에서 지도 선택시 event setting 업데이트")
        expect.count = 2
        let viewModel = self.makeViewModel()
        
        // when
        let settings = try await self.outputs(expect, for: self.spyEventSettingUsecase.currentEventSetting) {
            
            viewModel.toggleAlwaysSelectThisMap()
            viewModel.selectMap(.google)
        }
        
        // then
        #expect(settings.map { $0.defaultMapApp } == [nil, .google])
        #expect(self.spyRouter.didOpenMap == true)
        #expect(self.spyRouter.didClosed == true)
    }
}

private final class SpyRouter: BaseSpyRouter, SelectMapAppDialogRouting, @unchecked Sendable {
    
    var didOpenMap: Bool?
    func openMap(with query: String, using app: SupportMapApps) {
        self.didOpenMap = true
    }
}
