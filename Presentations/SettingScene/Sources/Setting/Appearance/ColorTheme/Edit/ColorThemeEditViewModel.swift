//
//  ColorThemeEditViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 10/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes
import CommonPresentation


// MARK: - ColorThemeEditSeedSlot

enum ColorThemeEditSeedSlot: CaseIterable {
    case text
    case surface
    case today
    case selectedDay
    case holidayOrWeekEnd
    case ai
}


// MARK: - ColorThemeEditViewModel

protocol ColorThemeEditViewModel: AnyObject, Sendable, ColorThemeEditSceneInteractor {

    // interactor
    func enterName(_ name: String)
    func selectBackground(hex: String)
    func selectAccent(hex: String)
    func selectForm(_ form: CustomColorThemeForm)
    func toggleSeed(_ slot: ColorThemeEditSeedSlot, isOn: Bool)
    func selectSeed(_ slot: ColorThemeEditSeedSlot, hex: String)
    func save()
    func delete()
    func close()

    // presenter
    var initialName: String? { get }
    var previewColorSet: AnyPublisher<ColorThemeDefinition, Never> { get }
    var seeds: AnyPublisher<CustomColorThemeSeeds, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isDeletable: Bool { get }
    var isProcessing: AnyPublisher<Bool, Never> { get }
}


// MARK: - ColorThemeEditViewModelImple

final class ColorThemeEditViewModelImple: ColorThemeEditViewModel, @unchecked Sendable {

    private let original: CustomColorTheme?
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any ColorThemeEditRouting)?
    weak var listener: (any ColorThemeEditSceneListener)?

    init(
        original: CustomColorTheme?,
        initialSeeds: CustomColorThemeSeeds,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.original = original
        self.uiSettingUsecase = uiSettingUsecase

        self.subject.name.send(original?.name ?? "")
        self.subject.seeds.send(initialSeeds)
    }


    private struct Subject {
        let name = CurrentValueSubject<String, Never>("")
        let seeds = CurrentValueSubject<CustomColorThemeSeeds?, Never>(nil)
        let isProcessing = CurrentValueSubject<Bool, Never>(false)
    }

    private let subject = Subject()
    private let cancellables = CancelBag()
}


// MARK: - ColorThemeEditViewModelImple Interactor

extension ColorThemeEditViewModelImple {

    func enterName(_ name: String) {
        self.subject.name.send(name)
    }

    func selectBackground(hex: String) {
        self.updateSeeds { $0.replacing(background: hex) }
    }

    func selectAccent(hex: String) {
        self.updateSeeds { $0.replacing(accent: hex) }
    }

    func selectForm(_ form: CustomColorThemeForm) {
        self.updateSeeds { $0.replacing(form: form) }
    }

    func toggleSeed(_ slot: ColorThemeEditSeedSlot, isOn: Bool) {
        guard isOn else {
            self.updateSeeds { $0 |> slot.keyPath .~ nil }
            return
        }
        self.updateSeeds { seeds in
            guard let definition = seeds.previewDefinition() else { return seeds }
            return seeds |> slot.keyPath .~ slot.token(of: definition).rgbHexString
        }
    }

    func selectSeed(_ slot: ColorThemeEditSeedSlot, hex: String) {
        self.updateSeeds { $0 |> slot.keyPath .~ hex }
    }

    private func updateSeeds(_ transform: (CustomColorThemeSeeds) -> CustomColorThemeSeeds) {
        guard let seeds = self.subject.seeds.value else { return }
        self.subject.seeds.send(transform(seeds))
    }

    func save() {
        guard self.isSavableNow, let theme = self.makeThemeToSave() else { return }
        self.subject.isProcessing.send(true)
        Task { [weak self] in
            do {
                try await self?.uiSettingUsecase.saveCustomColorTheme(theme)
                self?.finish(
                    message: "setting.appearance.calendar.colorTheme.edit::saved::message".localized()
                ) { [weak self] in
                    self?.listener?.customColorTheme(saved: theme)
                }
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isProcessing.send(false)
        }
        .store(in: self.cancellables)
    }

    func delete() {
        guard !self.subject.isProcessing.value else { return }
        guard let uuid = self.original?.uuid else { return }
        let remove = ActionSheetForm.Action("common.remove".localized(), style: .destructive) { [weak self] in
            self?.deleteTheme(uuid)
        }
        let cancel = ActionSheetForm.Action("common.cancel".localized(), style: .cancel)
        let form = ActionSheetForm()
            |> \.message .~ "setting.appearance.calendar.colorTheme.edit::delete::confirm::message".localized()
            |> \.actions .~ [remove, cancel]
        self.router?.showActionSheet(form)
    }

    private func deleteTheme(_ uuid: String) {
        guard !self.subject.isProcessing.value else { return }
        self.subject.isProcessing.send(true)
        Task { [weak self] in
            do {
                try await self?.uiSettingUsecase.removeCustomColorTheme(uuid)
                self?.finish(
                    message: "setting.appearance.calendar.colorTheme.edit::removed::message".localized()
                ) { [weak self] in
                    self?.listener?.customColorTheme(removed: uuid)
                }
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isProcessing.send(false)
        }
        .store(in: self.cancellables)
    }

    func close() {
        self.router?.closeScene(animate: true, nil)
    }

    private func finish(
        message: String,
        andNotify notify: @Sendable @escaping () -> Void
    ) {
        self.router?.showToast(message)
        self.router?.closeScene(animate: true) {
            notify()
        }
    }

    private var isSavableNow: Bool {
        return self.canSave(
            name: self.subject.name.value,
            isProcessing: self.subject.isProcessing.value
        )
    }

    private func canSave(name: String, isProcessing: Bool) -> Bool {
        return name.isNotBlank && !isProcessing
    }

    private func makeThemeToSave() -> CustomColorTheme? {
        guard let seeds = self.subject.seeds.value,
              let colors = seeds.previewDefinition()?.exportedColors
        else { return nil }
        let now = Date().timeIntervalSince1970
        return CustomColorTheme(
            uuid: self.original?.uuid ?? UUID().uuidString,
            name: self.subject.name.value.trimmedName,
            schemaVersion: Constant.schemaVersion,
            seeds: seeds,
            colors: colors,
            createdAt: self.original?.createdAt ?? now,
            updatedAt: now
        )
    }
}


// MARK: - ColorThemeEditViewModelImple Presenter

extension ColorThemeEditViewModelImple {

    var initialName: String? {
        return self.original?.name
    }

    var previewColorSet: AnyPublisher<ColorThemeDefinition, Never> {
        return self.subject.seeds
            .compactMap { $0 }
            .removeDuplicates()
            .compactMap { $0.previewDefinition() }
            .eraseToAnyPublisher()
    }

    var seeds: AnyPublisher<CustomColorThemeSeeds, Never> {
        return self.subject.seeds
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var isSavable: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest(
            self.subject.name,
            self.subject.isProcessing
        )
        .map { [weak self] name, isProcessing in
            return self?.canSave(name: name, isProcessing: isProcessing) ?? false
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }

    var isDeletable: Bool {
        return self.original != nil
    }

    var isProcessing: AnyPublisher<Bool, Never> {
        return self.subject.isProcessing
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}


// MARK: - private helpers

private extension String {

    var trimmedName: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isNotBlank: Bool {
        return !self.trimmedName.isEmpty
    }
}

private extension CustomColorThemeSeeds {

    func replacing(
        background: String? = nil,
        accent: String? = nil,
        form: CustomColorThemeForm? = nil
    ) -> CustomColorThemeSeeds {
        return CustomColorThemeSeeds(
            background: background ?? self.background,
            accent: accent ?? self.accent,
            form: form ?? self.form
        )
        |> \.text .~ self.text
        |> \.surface .~ self.surface
        |> \.today .~ self.today
        |> \.selectedDay .~ self.selectedDay
        |> \.holidayOrWeekEnd .~ self.holidayOrWeekEnd
        |> \.ai .~ self.ai
    }

    func previewDefinition() -> ColorThemeDefinition? {
        return CustomColorTheme(
            uuid: "",
            name: "",
            schemaVersion: Constant.schemaVersion,
            seeds: self,
            colors: [:],
            createdAt: 0,
            updatedAt: 0
        )
        .definition()
    }
}

private extension ColorThemeEditSeedSlot {

    var keyPath: WritableKeyPath<CustomColorThemeSeeds, String?> {
        switch self {
        case .text: return \.text
        case .surface: return \.surface
        case .today: return \.today
        case .selectedDay: return \.selectedDay
        case .holidayOrWeekEnd: return \.holidayOrWeekEnd
        case .ai: return \.ai
        }
    }

    func token(of definition: ColorThemeDefinition) -> UIColor {
        switch self {
        case .text: return definition.text0
        case .surface: return definition.bg1
        case .today: return definition.todayBackground
        case .selectedDay: return definition.selectedDayBackground
        case .holidayOrWeekEnd: return definition.holidayOrWeekEndWithAccent
        case .ai: return definition.accentAI
        }
    }
}

private enum Constant {
    static let schemaVersion: Int = 1
}
