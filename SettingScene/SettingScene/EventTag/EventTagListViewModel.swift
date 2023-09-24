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
    func loadMore()
    
    // presenter
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> { get }
}


// MARK: - EventTagListViewModelImple

final class EventTagListViewModelImple: EventTagListViewModel, @unchecked Sendable {
    
    private let tagListUsecase: EventTagListUsecase
    var router: (any EventTagListRouting)?
    
    init(
        tagListUsecase: EventTagListUsecase
    ) {
        self.tagListUsecase = tagListUsecase
        
        self.internalBind()
    }
    
    
    private struct Subject {
        
        let tags = CurrentValueSubject<[EventTag]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBind() {
     
        self.tagListUsecase.eventTags
            .sink(receiveValue: { [weak self] tags in
                self?.subject.tags.send(tags)
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - EventTagListViewModelImple Interactor

extension EventTagListViewModelImple {
    
    func reload() {
        self.tagListUsecase.reload()
    }
    
    func loadMore() {
        self.tagListUsecase.loadMore()
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
