//
//  AppSettingUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 2023/10/08.
//

import XCTest
import Combine
import Prelude
import Optics
import UnitTestHelpKit
import TestDoubles

@testable import Domain


class AppSettingUsecaseImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyViewAppearanceStore: SpyViewAppearanceStore!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyViewAppearanceStore = .init()
    }
    
    override func tearDownWithError() throws {
        self.spyViewAppearanceStore = nil
        self.cancelBag = nil
    }
        
    private func makeUsecase(
        selectedColorSetKey: ColorSetKeys? = nil,
        customColorThemeRepository: StubCustomColorThemeRepository = .init(),
        repository: StubAppSettingRepository = .init()
    ) -> AppSettingUsecaseImple {
        if let key = selectedColorSetKey {
            repository.stubAppearanceSetting = AppearanceSettings(
                calendar: .init(colorSetKey: key, fontSetKey: .systemDefault),
                defaultTagColor: .init(holiday: "holiday", default: "default")
            )
        }
        let usecase = AppSettingUsecaseImple(
            appSettingRepository: repository,
            customColorThemeRepository: customColorThemeRepository,
            viewAppearanceStore: self.spyViewAppearanceStore,
            sharedDataStore: SharedDataStore()
        )
        return usecase
    }
    
    private func makeCustomTheme(_ uuid: String) -> CustomColorTheme {
        return CustomColorTheme(
            uuid: uuid, name: "theme-\(uuid)", schemaVersion: 1,
            seeds: .init(background: "#FFFFFF", accent: "#112233", form: .filled),
            colors: [:], createdAt: 0, updatedAt: 0
        )
    }
}


// MARK: - test ui setting

extension AppSettingUsecaseImpleTests {
    
    func testUsecase_loadAvailableColorThemes_listsSystemKeysThenEveryAppThemeKey() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let keys = try await usecase.loadAvailableColorThemes()
        
        // then
        let appThemeKeys = keys.compactMap { key -> AppThemeColorSetKey? in
            guard case .appTheme(let appThemeKey) = key else { return nil }
            return appThemeKey
        }
        XCTAssertEqual(keys.prefix(3).map { $0 }, [.systemTheme, .defaultLight, .defaultDark])
        XCTAssertEqual(appThemeKeys, AppThemeColorSetKey.allCases)
        XCTAssertEqual(keys.count, 3 + AppThemeColorSetKey.allCases.count)
    }
    
    func testUsecase_loadAppAppearanceSetting() async throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let setting = try await usecase.refreshAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.defaultTagColor.holiday, "holiday")
        XCTAssertEqual(setting.defaultTagColor.default, "default")
        XCTAssertEqual(setting.calendar.colorSetKey, .defaultLight)
        XCTAssertEqual(setting.calendar.fontSetKey, .systemDefault)
    }
    
    func testUsecase_whenAfterLoadSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 조회 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentCalendarUISeting) {
            Task {
                let _ = try await usecase.refreshAppearanceSetting()
            }
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testUsecase_whenchangeCalendarSettingWithInsufficientParams_error() {
        // given
        let usecase = self.makeUsecase()
        var failed: Error?
        // when
        let params = EditCalendarAppearanceSettingParams()
        do {
            _ = try usecase.changeCalendarAppearanceSetting(params)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testUsecase_changeCalendarAppearnaceSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditCalendarAppearanceSettingParams()
            |> \.animationEffectIsOn .~ true
        let newValue = try? usecase.changeCalendarAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValue?.animationEffectIsOn, true)
    }
    
    func testUsecase_whenAfterchangeCalendarSetting_notifyToViewAppearanceStore() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditCalendarAppearanceSettingParams()
            |> \.animationEffectIsOn .~ true
        let _ = try? usecase.changeCalendarAppearanceSetting(params)
        
        // then
        XCTAssertEqual(self.spyViewAppearanceStore.didChangedCalendarSetting?.animationEffectIsOn, true)
    }
    
    func testUsecase_whenChangetagSettingWithInsufficientParams_error() async {
        // given
        let usecase = self.makeUsecase()
        var failed: Error?
        // when
        let params = EditDefaultEventTagColorParams()
        do {
            _ = try await usecase.changeDefaultEventTagColor(params)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testUsecase_changeDefaultTagColorAppearnaceSetting() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditDefaultEventTagColorParams()
            |> \.newDefaultTagColor .~ "new"
        let newValue = try? await usecase.changeDefaultEventTagColor(params)
        
        // then
        XCTAssertEqual(newValue?.default, "new")
    }
    
    func testUsecase_whenAfterChangeTagColorSetting_notifyToViewAppearanceStore() async {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditDefaultEventTagColorParams()
            |> \.newDefaultTagColor .~ "new"
        let _ = try? await usecase.changeDefaultEventTagColor(params)
        
        // then
        XCTAssertEqual(self.spyViewAppearanceStore.didChangedDefaultTagColor?.default, "new")
    }
    
    func testUsecase_whenAfterChangeSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 변경 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentCalendarUISeting) {
            let params = EditCalendarAppearanceSettingParams()
                |> \.animationEffectIsOn .~ true
            let _ = try? usecase.changeCalendarAppearanceSetting(params)
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testUsecase_changeWidgetAppearnaceSetting() throws {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditWidgetAppearanceSettingParams() |> \.background .~ .custom(hex: "custom")
        let newValue = try usecase.changeWidgetAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValue.background, .custom(hex: "custom"))
    }
}


// MARK: - test event setting

extension AppSettingUsecaseImpleTests {
    
    func testUsecase_loadEventSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let setting = usecase.loadEventSetting()
        
        // then
        XCTAssertEqual(setting.defaultNewEventTagId, .default)
        XCTAssertEqual(setting.defaultNewEventPeriod, .minute0)
    }
    
    func testUsecase_whenAfterLoadEventSettingSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 조회 이후에 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentEventSetting) {
            let _ = usecase.loadEventSetting()
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testUsecase_whenChangeEventSettingWithInsufficientParams_error() {
        // given
        let usecase = self.makeUsecase()
        var failed: Error?
        // when
        let params = EditEventSettingsParams()
        do {
            _ = try usecase.changeEventSetting(params)
        } catch {
            failed = error
        }
        
        // then
        XCTAssertNotNil(failed)
    }
    
    func testUsecase_changeEventSetting() {
        // given
        let usecase = self.makeUsecase()
        
        // when
        let params = EditEventSettingsParams()
            |> \.defaultNewEventPeriod .~ .allDay
            |> \.defaultNewEventTagId .~ .holiday
        let newValue = try? usecase.changeEventSetting(params)
        
        // then
        XCTAssertEqual(newValue?.defaultNewEventTagId, .holiday)
        XCTAssertEqual(newValue?.defaultNewEventPeriod, .allDay)
    }
    
    func testUsecase_whenAfterChangeEventSetting_notifyByCurrentSetting() {
        // given
        let expect = expectation(description: "setting 업데이트 이후 현재 세팅 전파")
        let usecase = self.makeUsecase()
        
        // when
        let setting = self.waitFirstOutput(expect, for: usecase.currentEventSetting) {
            let params = EditEventSettingsParams()
                |> \.defaultNewEventPeriod .~ .allDay
            let _ = try? usecase.changeEventSetting(params)
        }
        
        // then
        XCTAssertNotNil(setting)
    }
}

// MARK: - test custom color theme

extension AppSettingUsecaseImpleTests {
    
    func testUsecase_refreshAppearance_whenKeyIsCustom_fillsCurrentTheme() async throws {
        // given
        let theme = self.makeCustomTheme("c1")
        let usecase = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: .init(themes: [self.makeCustomTheme("other"), theme])
        )
        
        // when
        let setting = try await usecase.refreshAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.calendar.currentCustomColorTheme, theme)
        XCTAssertEqual(self.spyViewAppearanceStore.didSettignCahngedTo?.calendar.currentCustomColorTheme, theme)
    }
    
    func testUsecase_refreshAppearance_whenKeyIsNotCustom_doesNotFillTheme() async throws {
        // given
        let usecase = self.makeUsecase(
            selectedColorSetKey: .defaultDark,
            customColorThemeRepository: .init(themes: [self.makeCustomTheme("c1")])
        )
        
        // when
        let setting = try await usecase.refreshAppearanceSetting()
        
        // then
        XCTAssertNil(setting.calendar.currentCustomColorTheme)
    }
    
    func testUsecase_refreshAppearance_whenThemeReadFailsOrMissing_themeIsNil() async throws {
        // given
        let failing = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: .init(themes: [self.makeCustomTheme("c1")], shouldFailLoad: true)
        )
        let missing = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: .init(themes: [self.makeCustomTheme("other")])
        )
        
        // when
        let failed = try await failing.refreshAppearanceSetting()
        let notFound = try await missing.refreshAppearanceSetting()
        
        // then
        XCTAssertEqual(failed.calendar.colorSetKey, .custom("c1"))
        XCTAssertNil(failed.calendar.currentCustomColorTheme)
        XCTAssertNil(notFound.calendar.currentCustomColorTheme)
    }
    
    func testUsecase_loadSavedAppearance_whenKeyStaysCustom_keepsCurrentTheme() async throws {
        // given
        let usecase = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: .init(themes: [self.makeCustomTheme("c1")])
        )
        _ = try await usecase.refreshAppearanceSetting()
        
        // when
        let setting = usecase.loadSavedAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.calendar.currentCustomColorTheme?.uuid, "c1")
        XCTAssertEqual(self.spyViewAppearanceStore.didSettignCahngedTo?.calendar.currentCustomColorTheme?.uuid, "c1")
    }
    
    func testUsecase_loadSavedAppearance_whenKeyChangedToOther_clearsTheme() async throws {
        // given
        let repository = StubAppSettingRepository()
        let usecase = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: .init(themes: [self.makeCustomTheme("c1")]),
            repository: repository
        )
        _ = try await usecase.refreshAppearanceSetting()
        repository.stubAppearanceSetting = AppearanceSettings(
            calendar: .init(colorSetKey: .custom("c2"), fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "holiday", default: "default")
        )
        
        // when
        let setting = usecase.loadSavedAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.calendar.colorSetKey, .custom("c2"))
        XCTAssertNil(setting.calendar.currentCustomColorTheme)
    }
    
    func testUsecase_loadSavedAppearance_whenStoreIsEmpty_themeIsNil() {
        // given
        let usecase = self.makeUsecase(selectedColorSetKey: .custom("c1"))
        
        // when
        let setting = usecase.loadSavedAppearanceSetting()
        
        // then
        XCTAssertEqual(setting.calendar.colorSetKey, .custom("c1"))
        XCTAssertNil(setting.calendar.currentCustomColorTheme)
    }
    
    func testUsecase_changeCalendarSetting_whenKeyStaysCustom_keepsCurrentTheme() async throws {
        // given
        let theme = self.makeCustomTheme("c1")
        let usecase = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: .init(themes: [theme])
        )
        _ = try await usecase.refreshAppearanceSetting()
        
        // when
        let params = EditCalendarAppearanceSettingParams() |> \.animationEffectIsOn .~ true
        let newValue = try usecase.changeCalendarAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValue.animationEffectIsOn, true)
        XCTAssertEqual(newValue.currentCustomColorTheme, theme)
        XCTAssertEqual(self.spyViewAppearanceStore.didChangedCalendarSetting?.currentCustomColorTheme, theme)
    }
    
    func testUsecase_changeCalendarSetting_whenKeyChangesToOtherCustom_clearsTheme() async throws {
        // given
        let usecase = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: .init(themes: [self.makeCustomTheme("c1")])
        )
        _ = try await usecase.refreshAppearanceSetting()
        
        // when
        let params = EditCalendarAppearanceSettingParams() |> \.newColorSetKey .~ .custom("c2")
        let newValue = try usecase.changeCalendarAppearanceSetting(params)
        
        // then
        XCTAssertEqual(newValue.colorSetKey, .custom("c2"))
        XCTAssertNil(newValue.currentCustomColorTheme)
    }
    
    func testUsecase_loadCustomColorThemes_returnsRepositoryList() async throws {
        // given
        let themes = [self.makeCustomTheme("a"), self.makeCustomTheme("b")]
        let usecase = self.makeUsecase(customColorThemeRepository: .init(themes: themes))
        
        // when
        let loaded = try await usecase.loadCustomColorThemes()
        
        // then
        XCTAssertEqual(loaded, themes)
        XCTAssertEqual(self.spyViewAppearanceStore.calendarNotifyCount, 0)
    }
    
    func testUsecase_saveCustomColorTheme_whenSelected_replacesCurrentThemeAndNotifies() async throws {
        // given
        let old = self.makeCustomTheme("c1")
        let repository = StubCustomColorThemeRepository(themes: [old])
        let usecase = self.makeUsecase(selectedColorSetKey: .custom("c1"), customColorThemeRepository: repository)
        _ = try await usecase.refreshAppearanceSetting()
        let updated = CustomColorTheme(
            uuid: "c1", name: "renamed", schemaVersion: 1,
            seeds: .init(background: "#000000", accent: "#112233", form: .filled),
            colors: [:], createdAt: 0, updatedAt: 5
        )
        let countBefore = self.spyViewAppearanceStore.calendarNotifyCount
        
        // when
        try await usecase.saveCustomColorTheme(updated)
        
        // then
        XCTAssertEqual(repository.didSavedThemes, [updated])
        XCTAssertEqual(self.spyViewAppearanceStore.calendarNotifyCount, countBefore + 1)
        XCTAssertEqual(self.spyViewAppearanceStore.didChangedCalendarSetting?.currentCustomColorTheme, updated)
    }
    
    func testUsecase_saveCustomColorTheme_whenNotSelected_savesWithoutNotify() async throws {
        // given
        let repository = StubCustomColorThemeRepository(themes: [self.makeCustomTheme("c1")])
        let usecase = self.makeUsecase(selectedColorSetKey: .custom("c1"), customColorThemeRepository: repository)
        _ = try await usecase.refreshAppearanceSetting()
        let countBefore = self.spyViewAppearanceStore.calendarNotifyCount
        let other = self.makeCustomTheme("other")
        
        // when
        try await usecase.saveCustomColorTheme(other)
        
        // then
        XCTAssertEqual(repository.didSavedThemes, [other])
        XCTAssertEqual(self.spyViewAppearanceStore.calendarNotifyCount, countBefore)
    }
    
    func testUsecase_removeCustomColorTheme_whenSelected_resetsColorSetKeyToSystemThemeAndNotifies() async throws {
        // given
        let repository = StubCustomColorThemeRepository(themes: [self.makeCustomTheme("c1")])
        let appSettingRepository = StubAppSettingRepository()
        let usecase = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: repository,
            repository: appSettingRepository
        )
        _ = try await usecase.refreshAppearanceSetting()
        let countBefore = self.spyViewAppearanceStore.calendarNotifyCount

        // when
        try await usecase.removeCustomColorTheme("c1")

        // then
        XCTAssertEqual(repository.didRemovedUuids, ["c1"])
        XCTAssertEqual(self.spyViewAppearanceStore.didChangedCalendarSetting?.colorSetKey, .systemTheme)
        XCTAssertNil(self.spyViewAppearanceStore.didChangedCalendarSetting?.currentCustomColorTheme)
        XCTAssertEqual(appSettingRepository.didChangeCalendarAppearanceSettingParams?.newColorSetKey, .systemTheme)
        XCTAssertEqual(self.spyViewAppearanceStore.calendarNotifyCount, countBefore + 1)
    }
    
    func testUsecase_removeCustomColorTheme_whenNotSelected_removesWithoutNotify() async throws {
        // given
        let repository = StubCustomColorThemeRepository(themes: [self.makeCustomTheme("c1")])
        let usecase = self.makeUsecase(selectedColorSetKey: .custom("c1"), customColorThemeRepository: repository)
        _ = try await usecase.refreshAppearanceSetting()
        let countBefore = self.spyViewAppearanceStore.calendarNotifyCount
        
        // when
        try await usecase.removeCustomColorTheme("other")
        
        // then
        XCTAssertEqual(repository.didRemovedUuids, ["other"])
        XCTAssertEqual(self.spyViewAppearanceStore.calendarNotifyCount, countBefore)
    }
    
    func testUsecase_whenSaveOrRemoveFails_doesNothing() async throws {
        // given
        let repository = StubCustomColorThemeRepository(
            themes: [self.makeCustomTheme("c1")], shouldFailSave: true, shouldFailRemove: true
        )
        let appSettingRepository = StubAppSettingRepository()
        let usecase = self.makeUsecase(
            selectedColorSetKey: .custom("c1"),
            customColorThemeRepository: repository,
            repository: appSettingRepository
        )
        _ = try await usecase.refreshAppearanceSetting()
        let countBefore = self.spyViewAppearanceStore.calendarNotifyCount

        // when
        var saveError: Error?
        var removeError: Error?
        do { try await usecase.saveCustomColorTheme(self.makeCustomTheme("c1")) } catch { saveError = error }
        do { try await usecase.removeCustomColorTheme("c1") } catch { removeError = error }

        // then
        XCTAssertNotNil(saveError)
        XCTAssertNotNil(removeError)
        XCTAssertEqual(self.spyViewAppearanceStore.calendarNotifyCount, countBefore)
        XCTAssertNil(appSettingRepository.didChangeCalendarAppearanceSettingParams)
    }
}

private class SpyViewAppearanceStore: ViewAppearanceStore, @unchecked Sendable {
 
    var didSettignCahngedTo: AppearanceSettings?
    func notifySettingChanged(_ newSetting: AppearanceSettings) {
        self.didSettignCahngedTo = newSetting
    }
    
    var didChangedCalendarSetting: CalendarAppearanceSettings?
    var calendarNotifyCount: Int = 0
    func notifyCalendarSettingChanged(_ newSetting: CalendarAppearanceSettings) {
        self.calendarNotifyCount += 1
        self.didChangedCalendarSetting = newSetting
    }
    
    var didChangedDefaultTagColor: DefaultEventTagColorSetting?
    func notifyDefaultEventTagColorChanged(_ newSetting: DefaultEventTagColorSetting) {
        self.didChangedDefaultTagColor = newSetting
    }
    
    func applyEventTagColors(_ tags: [any EventTag]) { }
}
