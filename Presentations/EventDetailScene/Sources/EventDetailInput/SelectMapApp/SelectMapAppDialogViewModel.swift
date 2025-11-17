//
//  
//  SelectMapAppDialogViewModel.swift
//  EventDetailScene
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


// MARK: - SelectMapAppDialogViewModel

protocol SelectMapAppDialogViewModel: AnyObject, Sendable, SelectMapAppDialogSceneInteractor {

    // interactor
    func selectMap(_ app: SupportMapApps)
    func toggleAlwaysSelectThisMap()
    func close()
    
    // presenter
    var alwaysSelectThisMapOption: AnyPublisher<Bool, Never> { get }
    var supportMapApps: [SupportMapApps] { get }
}


// MARK: - SelectMapAppDialogViewModelImple

final class SelectMapAppDialogViewModelImple: SelectMapAppDialogViewModel, @unchecked Sendable {
    
    let query: String
    let supportMapApps: [SupportMapApps]
    private let eventSettingUsecase: any EventSettingUsecase
    var router: (any SelectMapAppDialogRouting)?
    
    init(
        query: String,
        supportMapApps: [SupportMapApps],
        eventSettingUsecase: any EventSettingUsecase
    ) {
        self.query = query
        self.supportMapApps = supportMapApps
        self.eventSettingUsecase = eventSettingUsecase
    }
    
    
    private struct Subject {
        let alwaysSelectThisMapOption = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - SelectMapAppDialogViewModelImple Interactor

extension SelectMapAppDialogViewModelImple {
    
    func toggleAlwaysSelectThisMap() {
        let flag = self.subject.alwaysSelectThisMapOption.value
        self.subject.alwaysSelectThisMapOption.send(!flag)
    }
    
    func selectMap(_ app: SupportMapApps) {
        if self.subject.alwaysSelectThisMapOption.value == true {
            let param = EditEventSettingsParams() |> \.defaultMappApp .~ app
            _ = try? eventSettingUsecase.changeEventSetting(param)
        }
        self.router?.openMap(with: self.query, using: app)
        self.router?.closeScene()
    }
    
    func close() {
        self.router?.closeScene()
    }
}


// MARK: - SelectMapAppDialogViewModelImple Presenter

extension SelectMapAppDialogViewModelImple {
    
    var alwaysSelectThisMapOption: AnyPublisher<Bool, Never> {
        return self.subject.alwaysSelectThisMapOption
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
