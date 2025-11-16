//
//  EventDefaultMapAppViewModelImpleTests.swift
//  SettingSceneTests
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

@testable import SettingScene


class EventDefaultMapAppViewModelImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    private let spyEventSettingUsecase = StubEventSettingUsecase()
    private let spyRouter = SpyRouter()
    
    private func makeViewModel(
        defaultMapApp: SupportMapApps? = nil
    ) async throws -> EventDefaultMapAppViewModelImple {
        
        self.spyEventSettingUsecase.stubSetting = .init()
        self.spyEventSettingUsecase.stubSetting?.defaultMapApp = defaultMapApp
        _ = try await self.spyEventSettingUsecase.refreshEventSetting()
        
        let viewModel = EventDefaultMapAppViewModelImple(
            eventSettingUsecase: self.spyEventSettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension EventDefaultMapAppViewModelImpleTests {
    
    @Test("선택가능 지도 정보 제공", arguments: [nil, SupportMapApps.apple, .google])
    func viewModel_provideMapModels(_ map: SupportMapApps?) async throws {
        // given
        let expect = expectConfirm("provide models with select: \(map?.name ?? "nil")")
        let viewModel = try await self.makeViewModel(defaultMapApp: map)
        
        // when
        let models = try await firstOutput(expect, for: viewModel.mapModels)
        
        // then
        #expect(models?.map { $0.map } == [.apple, .google])
        let selecteds = models?.filter { $0.isSelected }.map { $0.map }
        if let map {
            #expect(selecteds == [map])
        } else{
            #expect(selecteds == [])
        }
    }
    
    // select -> update models
    @Test func viewModel_provideMapModelsWithSelection() async throws {
        // given
        let expect = expectConfirm("지도 선택에 따라 선택 값 업데이트")
        expect.count = 2
        let viewModel = try await self.makeViewModel()
        
        // when
        let models = try await self.outputs(expect, for: viewModel.mapModels) {
            viewModel.selectMap(.apple)
        }
        
        // then
        let selectMaps = models.map { ms in ms.filter {$0.isSelected}.map { $0.map } }
        #expect(selectMaps == [
            [], [.apple]
        ])
    }
    
    // select -> change setting
    @Test func viewModel_whenSelectMap_updateSetting() async throws {
        // given
        let expect = expectConfirm("지도 선택시 설정값 업데이트")
        expect.count = 2
        let viewModel = try await self.makeViewModel()
        
        // when
        let settings = try await self.outputs(expect, for: spyEventSettingUsecase.currentEventSetting.removeDuplicates()) {
            viewModel.selectMap(.google)
        }
        
        // then
        let maps = settings.map { $0.defaultMapApp }
        #expect(maps == [nil, .google])
    }
}

private final class SpyRouter: BaseSpyRouter, EventDefaultMapAppRouting, @unchecked Sendable { }
