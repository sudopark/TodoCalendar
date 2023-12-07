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
import Domain
import Scenes


// MARK: - AppearanceSettingViewModel

protocol AppearanceSettingViewModel: AnyObject, Sendable, AppearanceSettingSceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - AppearanceSettingViewModelImple

final class AppearanceSettingViewModelImple: AppearanceSettingViewModel, @unchecked Sendable {
    
    var router: (any AppearanceSettingRouting)?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - AppearanceSettingViewModelImple Interactor

extension AppearanceSettingViewModelImple {
    
}


// MARK: - AppearanceSettingViewModelImple Presenter

extension AppearanceSettingViewModelImple {
    
}
