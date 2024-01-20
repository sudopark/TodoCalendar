//
//  
//  EventNotificationDefaultTimeOptionViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 1/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - EventNotificationDefaultTimeOptionViewModel

protocol EventNotificationDefaultTimeOptionViewModel: AnyObject, Sendable, EventNotificationDefaultTimeOptionSceneInteractor {

    // interactor
    
    // presenter
}


// MARK: - EventNotificationDefaultTimeOptionViewModelImple

final class EventNotificationDefaultTimeOptionViewModelImple: EventNotificationDefaultTimeOptionViewModel, @unchecked Sendable {
    
    var router: (any EventNotificationDefaultTimeOptionRouting)?
    
    init() {
        
    }
    
    
    private struct Subject {
        
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventNotificationDefaultTimeOptionViewModelImple Interactor

extension EventNotificationDefaultTimeOptionViewModelImple {
    
}


// MARK: - EventNotificationDefaultTimeOptionViewModelImple Presenter

extension EventNotificationDefaultTimeOptionViewModelImple {
    
}
