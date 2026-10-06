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


struct ColorThemeModel: Equatable {
    let title: String
    let key: ColorSetKeys
    var isSelected: Bool = false
    let customColorTheme: CustomColorTheme?
    
    init(_ theme: CustomColorTheme) {
        self.key = .custom(theme.uuid)
        self.title = theme.name
        self.customColorTheme = theme
    }
    
    init(_ colorSetKey: ColorSetKeys) {
        self.key = colorSetKey
        self.customColorTheme = nil
        switch colorSetKey {
        case .systemTheme: self.title = "setting.appearance.calendar.colorTheme::system".localized()
        case .defaultLight: self.title = "setting.appearance.calendar.colorTheme::light".localized()
        case .defaultDark: self.title = "setting.appearance.calendar.colorTheme::dark".localized()
        case .appTheme(let key): self.title = key.definition.name.localized
        case .custom(let id): self.title = id
        }
    }
}

// MARK: - ColorThemeSelectViewModel

protocol ColorThemeSelectViewModel: AnyObject, Sendable, ColorThemeSelectSceneInteractor {

    // interactor
    func prepare()
    func selectTheme(_ model: ColorThemeModel)
    func createCustomTheme()
    func editCustomTheme(_ model: ColorThemeModel)
    func close()
    
    // presenter
    var sampleModel: AnyPublisher<CalendarAppearanceModel, Never> { get }
    var colorThemeModels: AnyPublisher<[ColorThemeModel], Never> { get }
    var customColorThemeModels: AnyPublisher<[ColorThemeModel], Never> { get }
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
    
    func selectTheme(_ model: ColorThemeModel) {
        self.applyTheme(model)
    }
    
    func createCustomTheme() {
        self.router?.routeToEditCustomTheme(original: nil, listener: self)
    }
    
    func editCustomTheme(_ model: ColorThemeModel) {
        guard let theme = model.customColorTheme else { return }
        self.router?.routeToEditCustomTheme(original: theme, listener: self)
    }
    
    private func applyTheme(_ model: ColorThemeModel) {
        do {
            if let theme = model.customColorTheme {
                let _ = try self.uiSettingUsecase.selectCustomColorTheme(theme)
            } else {
                let params = EditCalendarAppearanceSettingParams()
                    |> \.newColorSetKey .~ model.key
                let _ = try self.uiSettingUsecase.changeCalendarAppearanceSetting(params)
            }
        } catch {
            self.router?.showError(error)
        }
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
    
    var colorThemeModels: AnyPublisher<[ColorThemeModel], Never> {
        
        let transform: (ColorSetKeys, [ColorSetKeys]) -> [ColorThemeModel]
        transform = { current, availables in
            return availables.map { key in
                return ColorThemeModel(key) |> \.isSelected .~ (key == current)
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
    
    var customColorThemeModels: AnyPublisher<[ColorThemeModel], Never> {
        
        let transform: (ColorSetKeys, [CustomColorTheme]) -> [ColorThemeModel]
        transform = { current, themes in
            return themes.map { theme in
                let model = ColorThemeModel(theme)
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
            self.applyTheme(ColorThemeModel(theme))
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
