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
    
    private func makeCustomTheme(_ uuid: String, name: String? = nil) -> CustomColorTheme {
        return CustomColorTheme(
            uuid: uuid, name: name ?? "theme-\(uuid)", schemaVersion: 1,
            seeds: .init(background: "#FFFFFF", accent: "#112233", form: .filled),
            colors: [:], createdAt: 0, updatedAt: 0
        )
    }
    
    private func makeViewModel(
        customThemes: [CustomColorTheme] = []
    ) -> ColorThemeSelectViewModelImple {
        self.spyUISettingUsecase.stubCustomColorThemes = customThemes
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


// MARK: - custom themes

extension ColorThemeSelectViewModelImpleTests {
    
    private func prepareAndWaitCustomModels(
        _ viewModel: ColorThemeSelectViewModelImple
    ) -> [ColorThemeModel] {
        let expect = expectation(description: "커스텀 테마 목록 준비")
        expect.assertForOverFulfill = false
        return self.waitFirstOutput(expect, for: viewModel.customColorThemeModels) {
            viewModel.prepare()
        } ?? []
    }
    
    func testViewModel_provideCustomColorThemeModels_inRepositoryOrder() {
        // given
        let viewModel = self.makeViewModel(
            customThemes: [self.makeCustomTheme("b"), self.makeCustomTheme("a"), self.makeCustomTheme("c")]
        )
        
        // when
        let models = self.prepareAndWaitCustomModels(viewModel)
        
        // then
        XCTAssertEqual(models.map { $0.key }, [.custom("b"), .custom("a"), .custom("c")])
        XCTAssertEqual(models.map { $0.customColorTheme?.uuid }, ["b", "a", "c"])
        XCTAssertEqual(models.map { $0.isSelected }, [false, false, false])
    }
    
    func testViewModel_customColorThemeModelTitleIsThemeName() {
        // given
        let viewModel = self.makeViewModel(
            customThemes: [self.makeCustomTheme("a", name: "내 테마")]
        )
        
        // when
        let models = self.prepareAndWaitCustomModels(viewModel)
        
        // then
        XCTAssertEqual(models.map { $0.title }, ["내 테마"])
    }
    
    func testViewModel_colorThemeModels_excludeCustomThemes() {
        // given
        let expect = expectation(description: "기본 테마 목록에 커스텀 테마 제외")
        let viewModel = self.makeViewModel(customThemes: [self.makeCustomTheme("a")])
        
        // when
        let models = self.waitFirstOutput(expect, for: viewModel.colorThemeModels, timeout: 0.1) {
            viewModel.prepare()
        } ?? []
        
        // then
        XCTAssertEqual(models.count, 3 + AppThemeColorSetKey.allCases.count)
        XCTAssertEqual(models.filter { $0.customColorTheme != nil }.count, 0)
        XCTAssertEqual(models.filter { $0.key == .custom("a") }.count, 0)
    }
    
    func testViewModel_whenSelectCustomTheme_selectsWithTheme() {
        // given
        let themeA = self.makeCustomTheme("a")
        let themeB = self.makeCustomTheme("b")
        let viewModel = self.makeViewModel(customThemes: [themeA, themeB])
        _ = self.prepareAndWaitCustomModels(viewModel)
        let expect = expectation(description: "선택 표시 갱신")
        expect.expectedFulfillmentCount = 2
        
        // when
        let outputs = self.waitOutputs(expect, for: viewModel.customColorThemeModels) {
            viewModel.selectTheme(ColorThemeModel(themeB))
        }
        
        // then
        XCTAssertEqual(self.spyUISettingUsecase.didSelectCustomColorTheme, themeB)
        XCTAssertEqual(outputs.last?.filter { $0.isSelected }.map { $0.key }, [.custom("b")])
    }
    
    func testViewModel_whenSelectBuiltInTheme_changesKeyOnly() {
        // given
        let viewModel = self.makeViewModel(customThemes: [self.makeCustomTheme("a")])
        
        // when
        viewModel.selectTheme(.init(.defaultDark))
        
        // then
        XCTAssertNil(self.spyUISettingUsecase.didSelectCustomColorTheme)
        XCTAssertEqual(
            self.spyUISettingUsecase.didChangeAppearanceSetting?.calendar.colorSetKey, .defaultDark
        )
    }
    
    func testViewModel_createCustomTheme_routesToEditWithoutOriginal() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.createCustomTheme()
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToEditCustomTheme, true)
        XCTAssertNil(self.spyRouter.didRouteToEditCustomThemeOriginal)
        XCTAssertTrue(self.spyRouter.didRouteToEditCustomThemeListener === viewModel)
    }
    
    func testViewModel_editCustomTheme_routesToEditWithOriginal() {
        // given
        let themeA = self.makeCustomTheme("a")
        let viewModel = self.makeViewModel(customThemes: [themeA])
        
        // when
        viewModel.editCustomTheme(ColorThemeModel(themeA))
        viewModel.editCustomTheme(.init(.defaultDark))
        
        // then
        XCTAssertEqual(self.spyRouter.didRouteToEditCustomTheme, true)
        XCTAssertEqual(self.spyRouter.didRouteToEditCustomThemeOriginal, themeA)
        XCTAssertTrue(self.spyRouter.didRouteToEditCustomThemeListener === viewModel)
    }
    
    func testViewModel_whenNewThemeSaved_appendsAndApplies() {
        // given
        let newTheme = self.makeCustomTheme("new")
        let viewModel = self.makeViewModel(
            customThemes: [self.makeCustomTheme("a"), self.makeCustomTheme("b")]
        )
        _ = self.prepareAndWaitCustomModels(viewModel)
        let expect = expectation(description: "목록 추가 후 적용")
        expect.expectedFulfillmentCount = 3
        
        // when
        let outputs = self.waitOutputs(expect, for: viewModel.customColorThemeModels) {
            viewModel.customColorTheme(saved: newTheme)
        }
        
        // then
        XCTAssertEqual(outputs.last?.map { $0.key }, [.custom("a"), .custom("b"), .custom("new")])
        XCTAssertEqual(outputs.last?.filter { $0.isSelected }.map { $0.key }, [.custom("new")])
        XCTAssertEqual(self.spyUISettingUsecase.didSelectCustomColorTheme, newTheme)
    }
    
    func testViewModel_whenExistingThemeSaved_replacesWithoutApplying() {
        // given
        let renamed = self.makeCustomTheme("a", name: "renamed")
        let viewModel = self.makeViewModel(
            customThemes: [self.makeCustomTheme("a"), self.makeCustomTheme("b")]
        )
        _ = self.prepareAndWaitCustomModels(viewModel)
        let expect = expectation(description: "목록 제자리 교체")
        expect.expectedFulfillmentCount = 2
        
        // when
        let outputs = self.waitOutputs(expect, for: viewModel.customColorThemeModels) {
            viewModel.customColorTheme(saved: renamed)
        }
        
        // then
        XCTAssertEqual(outputs.last?.map { $0.key }, [.custom("a"), .custom("b")])
        XCTAssertEqual(outputs.last?.map { $0.title }, ["renamed", "theme-b"])
        XCTAssertNil(self.spyUISettingUsecase.didSelectCustomColorTheme)
    }
    
    func testViewModel_whenThemeRemoved_removesFromList() {
        // given
        let viewModel = self.makeViewModel(
            customThemes: [self.makeCustomTheme("a"), self.makeCustomTheme("b")]
        )
        _ = self.prepareAndWaitCustomModels(viewModel)
        let expect = expectation(description: "목록에서 제거")
        expect.expectedFulfillmentCount = 2
        
        // when
        let outputs = self.waitOutputs(expect, for: viewModel.customColorThemeModels) {
            viewModel.customColorTheme(removed: "a")
        }
        
        // then
        XCTAssertEqual(outputs.last?.map { $0.key }, [.custom("b")])
    }
}


private final class SpyRouter: BaseSpyRouter, ColorThemeSelectRouting, @unchecked Sendable {
    
    var didRouteToEditCustomTheme: Bool?
    var didRouteToEditCustomThemeOriginal: CustomColorTheme?
    var didRouteToEditCustomThemeListener: (any ColorThemeEditSceneListener)?
    func routeToEditCustomTheme(
        original: CustomColorTheme?,
        listener: (any ColorThemeEditSceneListener)?
    ) {
        self.didRouteToEditCustomTheme = true
        self.didRouteToEditCustomThemeOriginal = original
        self.didRouteToEditCustomThemeListener = listener
    }
}
