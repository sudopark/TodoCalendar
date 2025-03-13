//
//  EventTagListViewUsecase.swift
//  SettingScene
//
//  Created by sudo.park on 12/31/23.
//  Copyright © 2023 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


struct EventTagCellViewModel: Equatable {
    
    var isOn: Bool = true
    let id: EventTagId
    let name: String
    var colorHex: String
    
    init(_ tag: any EventTag) {
        self.id = tag.tagId
        self.name = tag.name
        self.colorHex = tag.colorHex
    }
}


final class EventTagListViewUsecase {
    
    private let tagUsecase: any EventTagUsecase
    init(tagUsecase: any EventTagUsecase) {
        self.tagUsecase = tagUsecase
    }
    
    private let allTags = CurrentValueSubject<[any EventTag]?, Never>(nil)
    private let occuredError = PassthroughSubject<any Error, Never>()
    private var cancellables: Set<AnyCancellable> = []
}

extension EventTagListViewUsecase {
    
    func reload() {
        
        let loaded: ([any EventTag]) -> Void = { [weak self] tags in
            self?.allTags.send(tags)
        }
        
        let handleError: (any Error) -> Void = { [weak self] error in
            self?.occuredError.send(error)
        }
        
        self.tagUsecase.loadAllEventTags()
            .sink(receiveValue: loaded, receiveError: handleError)
            .store(in: &self.cancellables)
    }
}

extension EventTagListViewUsecase {
    
    var reloadFailed: AnyPublisher<any Error, Never> {
        return self.occuredError
            .eraseToAnyPublisher()
    }
    
    var cellViewModels: AnyPublisher<[EventTagCellViewModel], Never> {
        let asCellViewModels: ([any EventTag]) -> [EventTagCellViewModel] = { tags in
            return tags
                .sortDefaultTagsAtFirst()
                .map { EventTagCellViewModel($0) }
        }
        
        let applyOnOff: ([EventTagCellViewModel], Set<EventTagId>) -> [EventTagCellViewModel] = { cvms, offTagIdSet in
            
            return cvms
                .map { $0 |> \.isOn .~ !offTagIdSet.contains($0.id) }
            
        }
        
        return Publishers.CombineLatest(
            self.allTags.compactMap { $0 }.map(asCellViewModels),
            self.tagUsecase.offEventTagIdsOnCalendar()
        )
        .map(applyOnOff)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}
