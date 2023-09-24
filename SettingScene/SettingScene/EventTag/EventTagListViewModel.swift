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
import Prelude
import Optics
import Domain
import Scenes


struct EventTagCellViewModel: Equatable {
    
    var isOn: Bool = true
    let id: String
    let name: String
    let colorHext: String
}

// MARK: - EventTagListViewModel

protocol EventTagListViewModel: AnyObject, Sendable, EventTagListSceneInteractor {

    // interactor
    func reload()
    func toggleIsOn(_ tagId: String)
    func close()
    func addNewTag()
    func showTagDetail(_ tagId: String)
    
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
    }
    
    
    private struct Subject {
        let tags = CurrentValueSubject<[EventTag]?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
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
    
    func close() {
        self.router?.closeScene()
    }
    
    func addNewTag() {
        // TODO: route to add new tag
    }
    
    func toggleIsOn(_ tagId: String) {
        self.tagUsecase.toggleEventTagIsOnCalendar(tagId)
    }
    
    func showTagDetail(_ tagId: String) {
        // TODO: show detail
    }
}


// MARK: - EventTagListViewModelImple Presenter

extension EventTagListViewModelImple {
    
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> {
        let transform: ([EventTag], Set<String>) -> [EventTagCellViewModel] = { tags, offTagIdSet in
            return tags
                .map {
                    EventTagCellViewModel(id: $0.uuid, name: $0.name, colorHext: $0.colorHex)
                    |> \.isOn .~ !offTagIdSet.contains($0.uuid)
                }
            
        }
        return Publishers.CombineLatest(
            self.subject.tags.compactMap { $0 },
            self.tagUsecase.offEventTagIdsOnCalendar()
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}
