//
//  
//  AppearanceSettingViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - AppearanceSettingViewModel

protocol AppearanceSettingViewModel: AnyObject, Sendable, AppearanceSettingSceneInteractor {

    // interactor
    func routeToSelectTimezone()
    func toggleIsOnHapticFeedback(_ newValue: Bool)
    func toggleMinimizeAnimationEffect(_ newValue: Bool)
    func close()
    
    // presenter
    var currentTimeZoneName: AnyPublisher<String, Never> { get }
    var hapticIsOn: AnyPublisher<Bool, Never> { get }
    var animationIsOn: AnyPublisher<Bool, Never> { get }
}


// MARK: - AppearanceSettingViewModelImple

final class AppearanceSettingViewModelImple: AppearanceSettingViewModel, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    var router: (any AppearanceSettingRouting)?
    
    init(
        setting: AppearanceSettings,
        calendarSettingUsecase: any CalendarSettingUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.subject.uiSetting.send(setting)
    }
    
    
    private struct Subject {
        let uiSetting = CurrentValueSubject<AppearanceSettings?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - AppearanceSettingViewModelImple Interactor

extension AppearanceSettingViewModelImple {
    
    func routeToSelectTimezone() {
        
        self.router?.routeToSelectTimeZone()
    }
    
    func toggleIsOnHapticFeedback(_ newValue: Bool) {
        guard let setting = self.subject.uiSetting.value,
              setting.hapticEffectIsOn != newValue
        else { return }
        
        let params = EditAppearanceSettingParams() |> \.hapticEffectIsOn .~ newValue
        self.updateSetting(params)
    }
    
    func toggleMinimizeAnimationEffect(_ newValue: Bool) {
        guard let setting = self.subject.uiSetting.value,
              setting.animationEffectIsOn != newValue
        else { return }
        
        let params = EditAppearanceSettingParams() |> \.animationEffectIsOn .~ newValue
        self.updateSetting(params)
    }
    
    private func updateSetting(_ params: EditAppearanceSettingParams) {
        do {
            let newSetting = try self.uiSettingUsecase.changeAppearanceSetting(params)
            self.subject.uiSetting.send(newSetting)
        } catch {
            self.router?.showError(error)
        }
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - AppearanceSettingViewModelImple Presenter

extension AppearanceSettingViewModelImple {
    
    var currentTimeZoneName: AnyPublisher<String, Never> {
        let transform: (TimeZone) -> String? = { timeZone in
            let systemTimeZone = TimeZone.current
            
            return systemTimeZone == timeZone
                ? "System Time".localized()
                : timeZone.localizedName(for: .generic, locale: .current)
        }
        
        return self.calendarSettingUsecase.currentTimeZone
            .compactMap(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var hapticIsOn: AnyPublisher<Bool, Never> {
        return self.subject.uiSetting
            .compactMap { $0?.hapticEffectIsOn }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var animationIsOn: AnyPublisher<Bool, Never> {
        return self.subject.uiSetting
            .compactMap { $0?.animationEffectIsOn }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
