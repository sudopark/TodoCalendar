//
//  
//  EventTagListViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import Foundation
import Combine
import Domain
import Scenes


struct EventTagCellViewModel: Equatable {
    
    let id: String
    let name: String
    let colorHext: String
}

// MARK: - EventTagListViewModel

protocol EventTagListViewModel: AnyObject, Sendable, EventTagListSceneInteractor {

    // interactor
    func reload()
    
    // presenter
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> { get }
}


// MARK: - EventTagListViewModelImple

final class EventTagListViewModelImple: EventTagListViewModel, @unchecked Sendable {
    
    private let tagUsecase: EventTagUsecase
    var router: (any EventTagListRouting)?
    
    init(
        tagUsecase: EventTagUsecase
    ) {
        self.tagUsecase = tagUsecase
        
        self.internalBind()
    }
    
    
    private struct Subject {
        
        let tags = CurrentValueSubject<[EventTag]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBind() {
     
        
    }
}


// MARK: - EventTagListViewModelImple Interactor

extension EventTagListViewModelImple {
    
    func reload() {
        
        let showError: (any Error) -> Void = { [weak self] error in
            self?.router?.showError(error)
        }
        let loaded: ([EventTag]) -> Void = { [weak self] tags in
            self?.subject.tags.send(tags)
        }
        
        self.tagUsecase.loadAllEventTags()
            .sink(receiveValue: loaded, receiveError: showError)
            .store(in: &self.cancellables)
    }
}


// MARK: - EventTagListViewModelImple Presenter

extension EventTagListViewModelImple {
    
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> {
        let transform: (EventTag) -> EventTagCellViewModel = {
            return .init(id: $0.uuid, name: $0.name, colorHext: $0.colorHex)
        }
        return self.subject.tags
            .compactMap { $0 }
            .map { $0.map(transform) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
