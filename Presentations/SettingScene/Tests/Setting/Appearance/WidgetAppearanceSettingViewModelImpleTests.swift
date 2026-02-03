//
//  WidgetAppearanceSettingViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 2/4/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import TestDoubles
import UnitTestHelpKit

@testable import SettingScene


final class WidgetAppearanceSettingViewModelImpleTests: PublisherWaitable {
    
    private let spyRouter = SpyRouter()
    private let spyUISettingUsecase = StubUISettingUsecase()
    var cancelBag: Set<AnyCancellable>! = []
 
    private func makeViewModel(_ background: WidgetAppearanceSettings.Background) -> WidgetAppearanceSettingViewModelImple {
        let setting = WidgetAppearanceSettings() |> \.background .~ background
        let viewModel = WidgetAppearanceSettingViewModelImple(setting: setting, uiSettingUsecase: spyUISettingUsecase)
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension WidgetAppearanceSettingViewModelImpleTests {
    
    // 초기값 system -> custom -> system으로 변경하는 경우
    @Test func viewModel_changeFromSystemToCustom() async throws {
        // given
        let expect = expectConfirm("초기값 system -> custom -> system으로 변경하는 경우")
        expect.count = 3; expect.timeout = .milliseconds(100)
        let viewModel = self.makeViewModel(.system)
        
        // when
        let backgrounds = try await self.outputs(expect, for: viewModel.background) {
            viewModel.selectCustomBackground(hex: "some")
            viewModel.selectSystemTheme()
        }
        
        // then
        #expect(backgrounds == [
            .system, .custom(hex: "some"), .system
        ])
    }
    
    // 초기값 custom -> system -> custom 으로 변경하는 경우
    @Test func viewModel_changeFromCustomToSystem() async throws {
        // given
        let expect = expectConfirm("초기값 custom -> system -> custom 으로 변경하는 경우")
        expect.count = 3; expect.timeout = .milliseconds(100)
        let viewModel = self.makeViewModel(.custom(hex: "some1"))
        
        // when
        let backgrounds = try await self.outputs(expect, for: viewModel.background) {
            viewModel.selectSystemTheme()
            viewModel.selectCustomBackground(hex: "some2")
        }
        
        // then
        #expect(backgrounds == [
            .custom(hex: "some1"), .system, .custom(hex: "some2")
        ])
    }
    
    // 설정값 변경 이후 세팅값 업데이트
    @Test func viewModel_changeSetting_updateSetting() {
        // given
        let viewModel = self.makeViewModel(.system)
        
        // when
        viewModel.selectCustomBackground(hex: "some")
        
        // then
        #expect(
            self.spyUISettingUsecase.didChangeAppearanceSetting?.widget.background == .custom(hex: "some")
        )
    }
}


private final class SpyRouter: BaseSpyRouter, WidgetAppearanceSettingRouting, @unchecked Sendable { }
