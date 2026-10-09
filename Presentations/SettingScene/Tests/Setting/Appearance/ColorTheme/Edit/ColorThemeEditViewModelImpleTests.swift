//
//  ColorThemeEditViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import UIKit
import Combine
import Prelude
import Optics
import Domain
import Scenes
import CommonPresentation
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


final class ColorThemeEditViewModelImpleTests: PublisherWaitable, AsyncEffectWaitable {

    var cancelBag: Set<AnyCancellable>! = []
    private let spyRouter = SpyRouter()
    private let spyListener = SpyListener()
    private let eventLog = EventLog()
    private let stubGateUsecase = StubColorThemePaidFeatureGateUsecase()

    init() {
        self.spyRouter.eventLog = self.eventLog
        self.spyListener.eventLog = self.eventLog
        self.spyListener.spyRouter = self.spyRouter
    }

    private var initialSeeds: CustomColorThemeSeeds {
        return CustomColorThemeSeeds(background: "#FFFFFF", accent: "#FF5722", form: .filled)
    }

    private var originalTheme: CustomColorTheme {
        let seeds = CustomColorThemeSeeds(background: "#101010", accent: "#00AAFF", form: .outlined)
            |> \.text .~ "#EEEEEE"
        return CustomColorTheme(
            uuid: "original-uuid",
            name: "original",
            schemaVersion: 1,
            seeds: seeds,
            colors: [:],
            createdAt: 100,
            updatedAt: 200
        )
    }

    private func makeViewModel(
        original: CustomColorTheme? = nil,
        shouldSaveFail: Bool = false,
        shouldRemoveFail: Bool = false,
        firstWeekDay: DayOfWeeks = .sunday,
        uiSettingUsecase: StubUISettingUsecase = StubUISettingUsecase(),
        canCreateWithoutAd: Bool = true,
        licenseDays: Int? = 7,
        adResult: RewardedAdResult? = nil
    ) -> (ColorThemeEditViewModelImple, StubUISettingUsecase) {
        let usecase = uiSettingUsecase
        usecase.shouldFailSaveCustomColorTheme = shouldSaveFail
        usecase.shouldFailRemoveCustomColorTheme = shouldRemoveFail
        let calendarSettingUsecase = StubCalendarSettingUsecase()
        calendarSettingUsecase.updateFirstWeekDay(firstWeekDay)
        self.stubGateUsecase.canCreateWithoutAd = canCreateWithoutAd
        self.stubGateUsecase.licenseDays = licenseDays
        self.spyRouter.stubAdResult = adResult
        let viewModel = ColorThemeEditViewModelImple(
            original: original,
            initialSeeds: original?.seeds ?? self.initialSeeds,
            calendarSettingUsecase: calendarSettingUsecase,
            uiSettingUsecase: usecase,
            paidFeatureGateUsecase: self.stubGateUsecase
        )
        viewModel.router = self.spyRouter
        viewModel.listener = self.spyListener
        self.spyRouter.actionSheetSelectionMocking = { form in
            form.actions.first(where: { $0.style == .destructive })
        }
        return (viewModel, usecase)
    }

    private func currentSeeds(
        _ viewModel: ColorThemeEditViewModelImple
    ) async throws -> CustomColorThemeSeeds? {
        let expect = expectConfirm("현재 시드 제공")
        return try await self.firstOutput(expect, for: viewModel.seeds)
    }

    private func definition(of seeds: CustomColorThemeSeeds) -> ColorThemeDefinition? {
        return CustomColorTheme(
            uuid: "", name: "", schemaVersion: 1, seeds: seeds,
            colors: [:], createdAt: 0, updatedAt: 0
        )
        .definition()
    }
}


// MARK: - 새로 만들 때

extension ColorThemeEditViewModelImpleTests {

    @Test func viewModel_whenNew_providesInitialSeedsAndNotDeletable() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()

        // when
        let seeds = try await self.currentSeeds(viewModel)

        // then
        #expect(seeds == self.initialSeeds)
        #expect(viewModel.initialName == nil)
        #expect(viewModel.isDeletable == false)
    }

    @Test func viewModel_providesSampleModelFromFirstWeekDay() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(firstWeekDay: .monday)

        // when
        let expect = expectConfirm("샘플 모델 제공")
        let model = try await self.firstOutput(expect, for: viewModel.sampleModel)

        // then
        #expect(model?.weekDays.first == .monday)
    }

    @Test func viewModel_whenNew_saveCreatesThemeWithNewUuidAndComputedColors() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        viewModel.enterName("new theme")
        let before = Date().timeIntervalSince1970

        // when
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        let after = Date().timeIntervalSince1970
        let saved = try #require(usecase.didSaveCustomColorTheme)
        #expect(saved.uuid.isEmpty == false)
        #expect(saved.name == "new theme")
        #expect(saved.schemaVersion == 1)
        #expect(saved.seeds == self.initialSeeds)
        #expect(saved.colors == self.definition(of: self.initialSeeds)?.exportedColors)
        #expect((before...after).contains(saved.createdAt))
        #expect((before...after).contains(saved.updatedAt))
    }
}


// MARK: - 기존 테마를 열 때

extension ColorThemeEditViewModelImpleTests {

    @Test func viewModel_whenEdit_providesOriginalNameAndSeeds() async throws {
        // given
        let original = self.originalTheme
        let (viewModel, _) = self.makeViewModel(original: original)

        // when
        let seeds = try await self.currentSeeds(viewModel)

        // then
        #expect(viewModel.initialName == "original")
        #expect(seeds == original.seeds)
        #expect(viewModel.isDeletable == true)
    }

    @Test func viewModel_whenEdit_saveKeepsUuidAndCreatedAt() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(original: self.originalTheme)
        let before = Date().timeIntervalSince1970

        // when
        viewModel.selectAccent(hex: "#112233")
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        let saved = try #require(usecase.didSaveCustomColorTheme)
        #expect(saved.uuid == "original-uuid")
        #expect(saved.createdAt == 100)
        #expect(saved.updatedAt >= before)
        #expect(saved.seeds.accent == "#112233")
    }
}


// MARK: - 이름

extension ColorThemeEditViewModelImpleTests {

    @Test("이름이 비었거나 공백뿐이면 저장 불가", arguments: ["", "   ", " \n "])
    func viewModel_whenNameIsBlank_notSavable(_ name: String) async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        let expect = expectConfirm("저장 가능 여부 제공")
        expect.count = 3

        // when
        let values = try await self.outputs(expect, for: viewModel.isSavable) {
            viewModel.enterName("valid")
            viewModel.enterName(name)
        }
        viewModel.save()
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(values == [false, true, false])
        #expect(usecase.didSaveCustomColorTheme == nil)
    }

    @Test func viewModel_whenNameEntered_savable() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()
        let expect = expectConfirm("저장 가능 여부 제공")
        expect.count = 2

        // when
        let values = try await self.outputs(expect, for: viewModel.isSavable) {
            viewModel.enterName("name")
        }

        // then
        #expect(values == [false, true])
    }

    @Test func viewModel_trimsNameOnSave() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel()
        viewModel.enterName("  spaced name \n")

        // when
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        #expect(usecase.didSaveCustomColorTheme?.name == "spaced name")
    }
}


// MARK: - 처리 중

extension ColorThemeEditViewModelImpleTests {

    @Test func viewModel_whenSaving_emitsProcessingAndBlocksSave() async throws {
        // given
        let usecase = MockPendingUISettingUsecase()
        let (viewModel, _) = self.makeViewModel(uiSettingUsecase: usecase)
        viewModel.enterName("name")
        let processing = OutputCollector<Bool>()
        let savable = OutputCollector<Bool>()
        viewModel.isProcessing.sink { processing.append($0) }.store(in: &self.cancelBag)
        viewModel.isSavable.sink { savable.append($0) }.store(in: &self.cancelBag)

        // when
        viewModel.save()
        try await self.waitEffect("저장 대기 진입") { usecase.didRequestSaveThemes.count == 1 }
        try await self.waitEffect("처리 중 방출") { processing.values.last == true }
        viewModel.save()
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(savable.values.last == false)
        #expect(usecase.didRequestSaveThemes.count == 1)

        // when
        usecase.finishPendingSave()
        try await self.waitEffect("처리 종료") { processing.values.last == false }

        // then
        #expect(self.spyListener.didSaved?.name == "name")
    }

    @Test func viewModel_whenProcessing_ignoresDelete() async throws {
        // given
        let usecase = MockPendingUISettingUsecase()
        let (viewModel, _) = self.makeViewModel(
            original: self.originalTheme, uiSettingUsecase: usecase
        )

        // when
        viewModel.save()
        try await self.waitEffect("저장 대기 진입") { usecase.didRequestSaveThemes.count == 1 }
        viewModel.delete()
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyRouter.didShowActionSheetWith == nil)
        #expect(usecase.didRemoveCustomColorThemeUuid == nil)

        // when
        usecase.finishPendingSave()
        try await self.waitEffect("저장 통지") { self.spyListener.didSaved != nil }

        // then
        #expect(self.spyListener.didSaved?.uuid == "original-uuid")
        #expect(self.spyListener.didRemovedUuid == nil)
    }
}


// MARK: - 미리보기

extension ColorThemeEditViewModelImpleTests {

    @Test func viewModel_whenSeedChanges_updatesPreviewColorSet() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()
        let expect = expectConfirm("시드 변경에 따라 미리보기 갱신")
        expect.count = 2

        // when
        let sets = try await self.outputs(expect, for: viewModel.previewColorSet) {
            viewModel.selectBackground(hex: "#202020")
        }

        // then
        let changedSeeds = CustomColorThemeSeeds(
            background: "#202020", accent: "#FF5722", form: .filled
        )
        #expect(
            sets.first?.bg0.rgbHexString == self.definition(of: self.initialSeeds)?.bg0.rgbHexString
        )
        #expect(
            sets.last?.bg0.rgbHexString == self.definition(of: changedSeeds)?.bg0.rgbHexString
        )
        #expect(sets.first?.bg0.rgbHexString != sets.last?.bg0.rgbHexString)
    }

    @Test(
        "세부 색을 지정으로 켜면 현재 미리보기 토큰 색이 시드로 채워진다",
        arguments: ColorThemeEditSeedSlot.allCases
    )
    func viewModel_toggleSeedOn_fillsFromCurrentPreviewToken(
        _ slot: ColorThemeEditSeedSlot
    ) async throws {
        // given
        let (viewModel, _) = self.makeViewModel()
        let definition = try #require(self.definition(of: self.initialSeeds))
        let expectedHexes: [ColorThemeEditSeedSlot: String] = [
            .text: definition.text0.rgbHexString,
            .surface: definition.bg1.rgbHexString,
            .today: definition.todayBackground.rgbHexString,
            .selectedDay: definition.selectedDayBackground.rgbHexString,
            .holidayOrWeekEnd: definition.holidayOrWeekEndWithAccent.rgbHexString,
            .ai: definition.accentAI.rgbHexString
        ]

        // when
        viewModel.toggleSeed(slot, isOn: true)
        let seeds = try #require(try await self.currentSeeds(viewModel))

        // then
        let filled: String? = switch slot {
        case .text: seeds.text
        case .surface: seeds.surface
        case .today: seeds.today
        case .selectedDay: seeds.selectedDay
        case .holidayOrWeekEnd: seeds.holidayOrWeekEnd
        case .ai: seeds.ai
        }
        #expect(filled == expectedHexes[slot])
    }

    @Test func viewModel_whenRequiredSeedOrFormChanges_keepsDetailSeeds() async throws {
        // given
        let seeds = CustomColorThemeSeeds(background: "#101010", accent: "#00AAFF", form: .filled)
            |> \.text .~ "#111111"
            |> \.surface .~ "#222222"
            |> \.today .~ "#333333"
            |> \.selectedDay .~ "#444444"
            |> \.holidayOrWeekEnd .~ "#555555"
            |> \.ai .~ "#666666"
        let original = CustomColorTheme(
            uuid: "original-uuid", name: "original", schemaVersion: 1,
            seeds: seeds, colors: [:], createdAt: 100, updatedAt: 200
        )
        let (viewModel, usecase) = self.makeViewModel(original: original)

        // when
        viewModel.selectBackground(hex: "#AAAAAA")
        viewModel.selectAccent(hex: "#BBBBBB")
        viewModel.selectForm(.outlined)
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        let saved = try #require(usecase.didSaveCustomColorTheme?.seeds)
        let expected = CustomColorThemeSeeds(background: "#AAAAAA", accent: "#BBBBBB", form: .outlined)
            |> \.text .~ "#111111"
            |> \.surface .~ "#222222"
            |> \.today .~ "#333333"
            |> \.selectedDay .~ "#444444"
            |> \.holidayOrWeekEnd .~ "#555555"
            |> \.ai .~ "#666666"
        #expect(saved == expected)
    }

    @Test func viewModel_toggleSeedOff_clearsSeed() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(original: self.originalTheme)

        // when
        viewModel.toggleSeed(.text, isOn: false)
        let seeds = try await self.currentSeeds(viewModel)

        // then
        #expect(seeds?.text == nil)
        #expect(seeds?.background == "#101010")
    }
}


// MARK: - 저장·삭제 결과

extension ColorThemeEditViewModelImpleTests {

    @Test func viewModel_whenSaveSucceeds_closesAndNotifiesSaved() async throws {
        // given
        let (viewModel, _) = self.makeViewModel()
        viewModel.enterName("name")

        // when
        viewModel.save()
        try await self.waitEffect("저장 통지") { self.spyListener.didSaved != nil }

        // then
        #expect(self.spyListener.didSaved?.name == "name")
        #expect(self.eventLog.events == ["toast", "saved after close"])
        #expect(
            self.spyRouter.didShowToastWithMessage
                == "setting.appearance.calendar.colorTheme.edit::saved::message".localized()
        )
    }

    @Test func viewModel_whenSaveFails_showsErrorAndStays() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(shouldSaveFail: true)
        viewModel.enterName("name")

        // when
        viewModel.save()
        try await self.waitEffect("에러 노출") { self.spyRouter.didShowError != nil }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.eventLog.events.isEmpty)
        #expect(self.spyRouter.didClosed == nil)
        #expect(self.spyListener.didSaved == nil)
    }

    @Test func viewModel_whenDeleteConfirmed_removesClosesAndNotifiesRemoved() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(original: self.originalTheme)

        // when
        viewModel.delete()
        try await self.waitEffect("삭제 통지") { self.spyListener.didRemovedUuid != nil }

        // then
        #expect(
            self.spyRouter.didShowActionSheetWith?.actions.map { $0.style } == [.destructive, .cancel]
        )
        #expect(usecase.didRemoveCustomColorThemeUuid == "original-uuid")
        #expect(self.spyListener.didRemovedUuid == "original-uuid")
        #expect(self.eventLog.events == ["toast", "removed after close"])
        #expect(
            self.spyRouter.didShowToastWithMessage
                == "setting.appearance.calendar.colorTheme.edit::removed::message".localized()
        )
    }

    @Test func viewModel_whenDeleteFails_showsErrorAndStays() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(
            original: self.originalTheme, shouldRemoveFail: true
        )

        // when
        viewModel.delete()
        try await self.waitEffect("에러 노출") { self.spyRouter.didShowError != nil }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.eventLog.events.isEmpty)
        #expect(self.spyRouter.didClosed == nil)
        #expect(self.spyListener.didRemovedUuid == nil)
    }
}


// MARK: - 새 테마 저장 광고

extension ColorThemeEditViewModelImpleTests {

    @Test func viewModel_whenNewAndAdRequired_showsCreateGuide() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(canCreateWithoutAd: false, licenseDays: 5)
        viewModel.enterName("new theme")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyRouter.didShowColorThemeAdGuideWith?.purpose == .createTheme)
        #expect(self.spyRouter.didShowColorThemeAdGuideWith?.licenseDays == 5)
        #expect(usecase.didSaveCustomColorTheme == nil)
    }

    @Test("보상 완료·전면 대체면 사용권을 주고 저장한다", arguments: [
        RewardedAdResult.rewarded, .fallbackFullScreenShown
    ])
    func viewModel_whenCreateAdRewarded_grantsLicenseAndSaves(
        _ result: RewardedAdResult
    ) async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(canCreateWithoutAd: false, adResult: result)
        viewModel.enterName("new theme")
        let before = Date()

        // when
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        let grantedAt = try #require(self.stubGateUsecase.didGrantLicenseAt)
        #expect((before...Date()).contains(grantedAt))
        #expect(usecase.didSaveCustomColorTheme?.name == "new theme")
    }

    @Test func viewModel_whenCreateAdUnavailable_savesWithoutLicense() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(canCreateWithoutAd: false, adResult: .unavailable)
        viewModel.enterName("new theme")

        // when
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        #expect(usecase.didSaveCustomColorTheme?.name == "new theme")
        #expect(self.stubGateUsecase.didGrantLicenseAt == nil)
    }

    @Test func viewModel_whenCreateAdDismissedBeforeReward_staysWithoutSaving() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(
            canCreateWithoutAd: false, adResult: .dismissedBeforeReward
        )
        viewModel.enterName("new theme")

        // when
        viewModel.save()
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.spyRouter.didShowColorThemeAdGuideWith?.purpose == .createTheme)
        #expect(usecase.didSaveCustomColorTheme == nil)
        #expect(self.stubGateUsecase.didGrantLicenseAt == nil)
        #expect(self.spyRouter.didClosed == nil)
    }

    @Test func viewModel_whenCreateGuideShowing_blocksSaveAgain() async throws {
        // given
        let (viewModel, _) = self.makeViewModel(canCreateWithoutAd: false)
        viewModel.enterName("new theme")

        // when
        viewModel.save()
        self.spyRouter.didShowColorThemeAdGuideWith = nil
        viewModel.save()
        let expect = self.expectConfirm("시트가 떠 있는 동안 저장 불가")
        let isSavable = try await self.firstOutput(expect, for: viewModel.isSavable)

        // then
        #expect(isSavable == false)
        #expect(self.spyRouter.didShowColorThemeAdGuideWith == nil)
    }

    @Test func viewModel_whenCreateGuideClosedWithoutAd_savableAgainWithoutSaving() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(canCreateWithoutAd: false)
        viewModel.enterName("new theme")
        viewModel.save()

        // when
        self.spyRouter.didShowColorThemeAdGuideOnFinished?(nil)
        let expect = self.expectConfirm("시트를 닫으면 다시 저장 가능")
        let isSavable = try await self.firstOutput(expect, for: viewModel.isSavable)
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(isSavable == true)
        #expect(usecase.didSaveCustomColorTheme == nil)
        #expect(self.stubGateUsecase.didGrantLicenseAt == nil)
    }

    @Test func viewModel_whenCreateGuideFinishedTwice_handlesFirstResultOnly() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(canCreateWithoutAd: false)
        viewModel.enterName("new theme")
        viewModel.save()

        // when
        self.spyRouter.didShowColorThemeAdGuideOnFinished?(.unavailable)
        self.spyRouter.didShowColorThemeAdGuideOnFinished?(.rewarded)
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }
        try await Task.sleep(for: .milliseconds(50))

        // then
        #expect(self.stubGateUsecase.didGrantLicenseAt == nil)
    }

    @Test func viewModel_whenEditExisting_savesWithoutGuide() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(
            original: self.originalTheme, canCreateWithoutAd: false
        )

        // when
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        #expect(usecase.didSaveCustomColorTheme?.uuid == "original-uuid")
        #expect(self.spyRouter.didShowColorThemeAdGuideWith == nil)
    }

    @Test func viewModel_whenAdNotRequired_savesWithoutGuide() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(canCreateWithoutAd: true)
        viewModel.enterName("new theme")

        // when
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        #expect(usecase.didSaveCustomColorTheme?.name == "new theme")
        #expect(self.spyRouter.didShowColorThemeAdGuideWith == nil)
    }

    @Test func viewModel_whenLicenseDaysUnresolved_savesWithoutGuide() async throws {
        // given
        let (viewModel, usecase) = self.makeViewModel(canCreateWithoutAd: false, licenseDays: nil)
        viewModel.enterName("new theme")

        // when
        viewModel.save()
        try await self.waitEffect("저장 호출") { usecase.didSaveCustomColorTheme != nil }

        // then
        #expect(usecase.didSaveCustomColorTheme?.name == "new theme")
        #expect(self.spyRouter.didShowColorThemeAdGuideWith == nil)
    }
}


// MARK: - doubles

private final class EventLog: @unchecked Sendable {

    private let lock = NSLock()
    private var items: [String] = []

    func append(_ event: String) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.items.append(event)
    }

    var events: [String] {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.items
    }
}

private final class SpyRouter: BaseSpyRouter, ColorThemeEditRouting, @unchecked Sendable {

    var eventLog: EventLog?

    override func showToast(_ message: String) {
        super.showToast(message)
        self.eventLog?.append("toast")
    }

    var stubAdResult: RewardedAdResult?
    var didShowColorThemeAdGuideWith: (purpose: ColorThemeAdGuidePurpose, licenseDays: Int)?
    var didShowColorThemeAdGuideOnFinished: (@Sendable (RewardedAdResult?) -> Void)?
    func showColorThemeAdGuide(
        _ purpose: ColorThemeAdGuidePurpose,
        licenseDays: Int,
        onFinished: @escaping @Sendable (RewardedAdResult?) -> Void
    ) {
        self.didShowColorThemeAdGuideWith = (purpose, licenseDays)
        self.didShowColorThemeAdGuideOnFinished = onFinished
        guard let result = self.stubAdResult else { return }
        onFinished(result)
    }
}

private final class SpyListener: ColorThemeEditSceneListener, @unchecked Sendable {

    var eventLog: EventLog?
    weak var spyRouter: SpyRouter?

    private var closeState: String {
        return self.spyRouter?.didClosed == true ? "after close" : "before close"
    }

    var didSaved: CustomColorTheme?
    func customColorTheme(saved theme: CustomColorTheme) {
        self.didSaved = theme
        self.eventLog?.append("saved \(self.closeState)")
    }

    var didRemovedUuid: String?
    func customColorTheme(removed uuid: String) {
        self.didRemovedUuid = uuid
        self.eventLog?.append("removed \(self.closeState)")
    }
}


private final class OutputCollector<T>: @unchecked Sendable {

    private let lock = NSLock()
    private var items: [T] = []

    func append(_ item: T) {
        self.lock.lock(); defer { self.lock.unlock() }
        self.items.append(item)
    }

    var values: [T] {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.items
    }
}


private final class MockPendingUISettingUsecase: StubUISettingUsecase, @unchecked Sendable {

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var requested: [CustomColorTheme] = []

    var didRequestSaveThemes: [CustomColorTheme] {
        self.lock.lock(); defer { self.lock.unlock() }
        return self.requested
    }

    override func saveCustomColorTheme(_ theme: CustomColorTheme) async throws {
        await withCheckedContinuation { continuation in
            self.lock.lock(); defer { self.lock.unlock() }
            self.continuation = continuation
            self.requested.append(theme)
        }
        try await super.saveCustomColorTheme(theme)
    }

    func finishPendingSave() {
        self.lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.lock.unlock()
        continuation?.resume()
    }
}
