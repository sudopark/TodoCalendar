//
//  ColorThemeSelectViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 8/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class ColorThemeSelectViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spyUISettingUsecase: StubUISettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyUISettingUsecase = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyUISettingUsecase = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel() -> ColorThemeSelectViewModelImple {
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.prepare()
        _ = self.spyUISettingUsecase.loadSavedAppearanceSetting()
        let viewModel = ColorThemeSelectViewModelImple(
            calendarSettingUsecase: calendarSettingUsecase,
            uiSettingUsecase: self.spyUISettingUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}


extension ColorThemeSelectViewModelImpleTests {
    
    func testViewModel_provideCalendarSampleModel() {
        // given
        let expect = expectation(description: "캘린더 샘플 모델 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let model = self.waitFirstOutput(expect, for: viewModel.sampleModel) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertNotNil(model)
    }
    
    func testViewModel_provideColorThemeModels() {
        // given
        let expect = expectation(description: "선택가능 테마값 제공")
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.colorThemeModels) {
            viewModel.prepare()
        } ?? []
        
        // then
        XCTAssertEqual(models.map { $0.key }, [.systemTheme, .defaultLight, .defaultDark])
        XCTAssertEqual(models.map { $0.isSelected }, [false, true, false])
    }
    
    func testViewModel_whenSelectTheme_updateSelectedModel() {
        // given
        let expect = expectation(description: "선택테마 업데이트시에, 선택된값 반영하여 선택가능 테마 모델 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        viewModel.prepare()
        
        // when
        let models = self.waitOutputs(expect, for: viewModel.colorThemeModels, timeout: 0.1) {
            
            viewModel.selectTheme(.init(.systemTheme))
            viewModel.selectTheme(.init(.defaultDark))
        }
        
        // then
        let selectedKeys = models.map { ms in ms.filter { $0.isSelected }.map { $0.key } }
        XCTAssertEqual(selectedKeys, [
            [.defaultLight], [.systemTheme], [.defaultDark]
        ])
    }
    
    func testViewModel_whenSelectTheme_updateSelectedModels() {
        // given
        let expect = expectation(description: "선택테마 업데이트시에, 선택된값으로 저장")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let settings = self.waitOutputs(expect, for: spyUISettingUsecase.currentCalendarUISeting) {
            viewModel.prepare()
            viewModel.selectTheme(.init(.systemTheme))
            viewModel.selectTheme(.init(.defaultDark))
        }
        
        // then
        let colorThemeKeys = settings.map { $0.colorSetKey }
        XCTAssertEqual(colorThemeKeys, [
            .defaultLight, .systemTheme, .defaultDark
        ])
    }
}


private final class SpyRouter: BaseSpyRouter, ColorThemeSelectRouting, @unchecked Sendable { }
