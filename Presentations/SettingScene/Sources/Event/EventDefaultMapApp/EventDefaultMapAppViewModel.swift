//
//  
//  EventDefaultMapAppViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 11/16/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


// MARK: - EventDefaultMapAppViewModel


struct SupportMapAppModel: Equatable {
    let map: SupportMapApps
    var isSelected: Bool = false
}

protocol EventDefaultMapAppViewModel: AnyObject, Sendable, EventDefaultMapAppSceneInteractor {

    // interactor
    func close()
    func selectMap(_ map: SupportMapApps)
    
    // presenter
    var mapModels: AnyPublisher<[SupportMapAppModel], Never> { get }
}


// MARK: - EventDefaultMapAppViewModelImple

final class EventDefaultMapAppViewModelImple: EventDefaultMapAppViewModel, @unchecked Sendable {
    
    private let eventSettingUsecase: any EventSettingUsecase
    var router: (any EventDefaultMapAppRouting)?
    
    init(eventSettingUsecase: any EventSettingUsecase) {
        self.eventSettingUsecase = eventSettingUsecase
    }
    
    
    private struct Subject {}
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - EventDefaultMapAppViewModelImple Interactor

extension EventDefaultMapAppViewModelImple {
 
    func selectMap(_ map: SupportMapApps) {
        let params = EditEventSettingsParams() |> \.defaultMappApp .~ map
        do {
            _ = try self.eventSettingUsecase.changeEventSetting(params)
        } catch {
            self.router?.showToast("common.errorMessage".localized())
        }
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - EventDefaultMapAppViewModelImple Presenter

extension EventDefaultMapAppViewModelImple {
    
    var mapModels: AnyPublisher<[SupportMapAppModel], Never> {
        let transform: (SupportMapApps?) -> [SupportMapAppModel] = { selected in
            let allMaps: [SupportMapApps] = [.apple, .google]
            return allMaps.map {
                return .init(map: $0, isSelected: $0 == selected)
            }
        }
        return self.eventSettingUsecase.currentEventSetting
            .map { $0.defaultMapApp }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
