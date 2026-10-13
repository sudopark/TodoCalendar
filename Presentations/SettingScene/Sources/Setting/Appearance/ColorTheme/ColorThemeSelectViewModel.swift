//
//  
//  ColorThemeSelectViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 8/3/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes
import CommonPresentation


protocol ColorThemeModel: Sendable {
    var key: ColorSetKeys { get }
    var title: String { get }
    var isSelected: Bool { get }
    func colorSet(isSystemDarkTheme: Bool) -> any ColorSet
}

struct BuiltInColorThemeModel: ColorThemeModel, Equatable {
    let key: ColorSetKeys
    var isSelected: Bool = false

    /// 정의 없는 커스텀 키는 그릴 때 시스템 테마로 폴백하므로 모델도 시스템 테마로 둔다
    init(_ colorSetKey: ColorSetKeys) {
        if case .custom = colorSetKey {
            self.key = .systemTheme
        } else {
            self.key = colorSetKey
        }
    }

    var title: String {
        switch self.key {
        case .systemTheme, .custom: return "setting.appearance.calendar.colorTheme::system".localized()
        case .defaultLight: return "setting.appearance.calendar.colorTheme::light".localized()
        case .defaultDark: return "setting.appearance.calendar.colorTheme::dark".localized()
        case .appTheme(let key): return key.definition.name.localized
        }
    }

    func colorSet(isSystemDarkTheme: Bool) -> any ColorSet {
        return self.key.convert(isSystemDarkTheme: isSystemDarkTheme, customColorTheme: nil)
    }
}

struct CustomColorThemeModel: ColorThemeModel, Equatable {
    let theme: CustomColorTheme
    var isSelected: Bool = false

    init(_ theme: CustomColorTheme) {
        self.theme = theme
    }

    var key: ColorSetKeys { .custom(self.theme.uuid) }
    var title: String { self.theme.name }

    func colorSet(isSystemDarkTheme: Bool) -> any ColorSet {
        return self.key.convert(isSystemDarkTheme: isSystemDarkTheme, customColorTheme: self.theme)
    }
}

// MARK: - ColorThemeSelectViewModel

protocol ColorThemeSelectViewModel: AnyObject, Sendable, ColorThemeSelectSceneInteractor {

    // interactor
    func prepare()
    func selectTheme(_ model: any ColorThemeModel)
    func createCustomTheme()
    func editCustomTheme(_ model: CustomColorThemeModel)
    func close()
    
    // presenter
    var sampleModel: AnyPublisher<CalendarAppearanceModel, Never> { get }
    var colorThemeModels: AnyPublisher<[BuiltInColorThemeModel], Never> { get }
    var customColorThemeModels: AnyPublisher<[CustomColorThemeModel], Never> { get }
}


// MARK: - ColorThemeSelectViewModelImple

final class ColorThemeSelectViewModelImple: ColorThemeSelectViewModel, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any ColorThemeSelectRouting)?
    
    init(
        calendarSettingUsecase: any CalendarSettingUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
    }
    
    
    private struct Subject {
        let availableTheme = CurrentValueSubject<[ColorSetKeys]?, Never>(nil)
        let customThemes = CurrentValueSubject<[CustomColorTheme]?, Never>(nil)
        let isAdGuideInProgress = CurrentValueSubject<Bool, Never>(false)
    }
    
    private let cancellables = CancelBag()
    private let subject = Subject()
}


// MARK: - ColorThemeSelectViewModelImple Interactor

extension ColorThemeSelectViewModelImple {
    
    func prepare() {
        Task { [weak self] in
            do {
                let keys = try await self?.uiSettingUsecase.loadAvailableColorThemes()
                self?.subject.availableTheme.send(keys)
            } catch {
                self?.router?.showError(error)
            }
        }
        .store(in: self.cancellables)
        
        Task { [weak self] in
            do {
                let themes = try await self?.uiSettingUsecase.loadCustomColorThemes()
                self?.subject.customThemes.send(themes)
            } catch {
                self?.router?.showError(error)
            }
        }
        .store(in: self.cancellables)
    }
    
    func selectTheme(_ model: any ColorThemeModel) {
        guard self.subject.isAdGuideInProgress.value == false else { return }
        Task { [weak self] in
            do {
                _ = try await self?.uiSettingUsecase.selectColorTheme(model.key)
            } catch let reason as PaidFeatureGateFailReason {
                await self?.selectThemeAgainAfterAdGuide(model, reason)
            } catch {
                self?.router?.showError(error)
            }
        }
        .store(in: self.cancellables)
    }

    @MainActor
    private func selectThemeAgainAfterAdGuide(_ model: any ColorThemeModel, _ reason: PaidFeatureGateFailReason) {
        guard self.subject.isAdGuideInProgress.value == false else { return }
        self.subject.isAdGuideInProgress.send(true)
        self.router?.showPaidFeatureAdGuide(reason) { [weak self] shouldProceed in
            guard self?.subject.isAdGuideInProgress.value == true else { return }
            self?.subject.isAdGuideInProgress.send(false)
            guard shouldProceed else { return }
            self?.selectTheme(model)
        }
    }
    
    func createCustomTheme() {
        self.router?.routeToEditCustomTheme(original: nil, listener: self)
    }
    
    func editCustomTheme(_ model: CustomColorThemeModel) {
        self.router?.routeToEditCustomTheme(original: model.theme, listener: self)
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - ColorThemeSelectViewModelImple Presenter

extension ColorThemeSelectViewModelImple {
    
    var sampleModel: AnyPublisher<CalendarAppearanceModel, Never> {
        return self.calendarSettingUsecase.firstWeekDay
            .map { CalendarAppearanceModel($0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var colorThemeModels: AnyPublisher<[BuiltInColorThemeModel], Never> {
        
        let transform: (ColorSetKeys, [ColorSetKeys]) -> [BuiltInColorThemeModel]
        transform = { current, availables in
            return availables.map { key in
                return BuiltInColorThemeModel(key) |> \.isSelected .~ (key == current)
            }
        }
        
        return Publishers.CombineLatest(
            uiSettingUsecase.currentCalendarUISeting.map { $0.colorSetKey },
            self.subject.availableTheme.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var customColorThemeModels: AnyPublisher<[CustomColorThemeModel], Never> {
        
        let transform: (ColorSetKeys, [CustomColorTheme]) -> [CustomColorThemeModel]
        transform = { current, themes in
            return themes.map { theme in
                let model = CustomColorThemeModel(theme)
                return model |> \.isSelected .~ (model.key == current)
            }
        }
        
        return Publishers.CombineLatest(
            uiSettingUsecase.currentCalendarUISeting.map { $0.colorSetKey },
            self.subject.customThemes.compactMap { $0 }
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}


// MARK: - ColorThemeSelectViewModelImple + ColorThemeEditSceneListener

extension ColorThemeSelectViewModelImple: ColorThemeEditSceneListener {
    
    func customColorTheme(saved theme: CustomColorTheme) {
        let themes = self.subject.customThemes.value ?? []
        guard let index = themes.firstIndex(where: { $0.uuid == theme.uuid })
        else {
            self.subject.customThemes.send(themes + [theme])
            self.selectTheme(CustomColorThemeModel(theme))
            return
        }
        let replaced = themes.enumerated().map { $0.offset == index ? theme : $0.element }
        self.subject.customThemes.send(replaced)
    }
    
    func customColorTheme(removed uuid: String) {
        let themes = self.subject.customThemes.value ?? []
        self.subject.customThemes.send(themes.filter { $0.uuid != uuid })
    }
}
