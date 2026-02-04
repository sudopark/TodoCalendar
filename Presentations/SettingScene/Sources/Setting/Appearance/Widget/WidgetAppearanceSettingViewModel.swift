//
//  WidgetAppearanceSettingViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 2/3/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


protocol WidgetAppearanceSettingViewModel: AnyObject, Sendable, WidgetAppearanceSettingSceneInteractor {
    
    func selectSystemTheme()
    func selectCustomBackground(hex: String)
    func close()
    
    var background: AnyPublisher<WidgetAppearanceSettings.Background, Never> { get }
}

final class WidgetAppearanceSettingViewModelImple: WidgetAppearanceSettingViewModel, @unchecked Sendable {
    
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any WidgetAppearanceSettingRouting)?
    
    init(
        setting: WidgetAppearanceSettings,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.subject.setting.send(setting)
    }
    
    private struct Subject {
        let setting = CurrentValueSubject<WidgetAppearanceSettings?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}

extension WidgetAppearanceSettingViewModelImple {
    
    func selectSystemTheme() {
        let params = EditWidgetAppearanceSettingParams()
            |> \.background .~ .system
        self.change(params)
    }
    
    func selectCustomBackground(hex: String) {
        let params = EditWidgetAppearanceSettingParams()
            |> \.background .~ .custom(hex: hex)
        self.change(params)
    }
    
    private func change(_ params: EditWidgetAppearanceSettingParams) {
        do {
            let newSetting = try self.uiSettingUsecase.changeWidgetAppearanceSetting(params)
            self.subject.setting.send(newSetting)
        } catch {
            self.router?.showError(error)
        }
    }
    
    func close() {
        self.router?.closeScene()
    }
}

extension WidgetAppearanceSettingViewModelImple {
    
    var background: AnyPublisher<WidgetAppearanceSettings.Background, Never> {
        
        return self.subject.setting.compactMap { $0 }
            .map { $0.background }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
