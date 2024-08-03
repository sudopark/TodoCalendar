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
import Scenes


struct ColorThemeModel: Equatable {
    let title: String
    let key: ColorSetKeys
    var isSelected: Bool = false
    
    init(_ colorSetKey: ColorSetKeys) {
        self.key = colorSetKey
        switch colorSetKey {
        case .systemTheme: self.title = "System".localized()
        case .defaultLight: self.title = "Light".localized()
        case .defaultDark: self.title = "Dark".localized()
        }
    }
}

// MARK: - ColorThemeSelectViewModel

protocol ColorThemeSelectViewModel: AnyObject, Sendable, ColorThemeSelectSceneInteractor {

    // interactor
    func prepare()
    func selectTheme(_ model: ColorThemeModel)
    func close()
    
    // presenter
    var sampleModel: AnyPublisher<CalendarAppearanceModel, Never> { get }
    var colorThemeModels: AnyPublisher<[ColorThemeModel], Never> { get }
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
    }
    
    private var cancellables: Set<AnyCancellable> = []
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
        .store(in: &self.cancellables)
    }
    
    func selectTheme(_ model: ColorThemeModel) {
        do {
            let params = EditCalendarAppearanceSettingParams()
                |> \.newColorSetKey .~ model.key
            let _ = try self.uiSettingUsecase.changeCalendarAppearanceSetting(params)
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
}
