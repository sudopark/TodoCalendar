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
        let models = self.waitFirstOutput(expect, for: viewModel.colorThemeModels, timeout: 0.1) {
            viewModel.prepare()
        } ?? []
        
        // then
        let appThemeKeys = models.compactMap { model -> AppThemeColorSetKey? in
            guard case .appTheme(let key) = model.key else { return nil }
            return key
        }
        XCTAssertEqual(
            models.prefix(3).map { $0.key }, [.systemTheme, .defaultLight, .defaultDark]
        )
        XCTAssertEqual(appThemeKeys, AppThemeColorSetKey.allCases)
        XCTAssertEqual(models.count, 3 + AppThemeColorSetKey.allCases.count)
        XCTAssertEqual(models.prefix(3).map { $0.isSelected }, [false, true, false])
    }
    
    func testViewModel_appThemeTitleComesFromDefinitionName() {
        // given
        let expect = expectation(description: "기본 제공 테마 제목은 테마 정의가 든 이름에서 온다")
        let viewModel = self.makeViewModel()
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.colorThemeModels, timeout: 0.1) {
            viewModel.prepare()
        } ?? []
        
        // then
        let tomato = models.first { $0.key == .appTheme(.tomato) }
        XCTAssertEqual(
            tomato?.title, "setting.appearance.calendar.colorTheme::tomato".localized()
        )
    }
    
    func testViewModel_whenSelectTheme_updateSelectedModel() async throws {
        // given
        let viewModel = self.makeViewModel()
        viewModel.prepare()

        // when
        var selectedKeys: [[ColorSetKeys]] = []
        viewModel.colorThemeModels
            .sink { models in
                let keys = models.filter { $0.isSelected }.map { $0.key }
                selectedKeys.append(keys)
            }
            .store(in: &self.cancelBag)

        try await Task.sleep(for: .milliseconds(50))
        viewModel.selectTheme(.init(.systemTheme))
        try await Task.sleep(for: .milliseconds(50))
        viewModel.selectTheme(.init(.defaultDark))
        try await Task.sleep(for: .milliseconds(50))

        // then
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
