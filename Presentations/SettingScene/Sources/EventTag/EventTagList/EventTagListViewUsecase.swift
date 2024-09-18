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
    let id: AllEventTagId
    let name: String
    let color: EventTagColor
    
    static var `default`: EventTagCellViewModel {
        return .init(
            id: .default,
            name: "eventTag.defaults.default::name".localized(),
            color: .default
        )
    }
    
    static var holiday: EventTagCellViewModel {
        return .init(
            id: .holiday,
            name: "eventTag.defaults.holiday::name".localized(),
            color: .holiday
        )
    }
}


final class EventTagListViewUsecase {
    
    private let tagUsecase: any EventTagUsecase
    init(tagUsecase: any EventTagUsecase) {
        self.tagUsecase = tagUsecase
    }
    
    private let allTags = CurrentValueSubject<[EventTag]?, Never>(nil)
    private let occuredError = PassthroughSubject<any Error, Never>()
    private var cancellables: Set<AnyCancellable> = []
}

extension EventTagListViewUsecase {
    
    func reload() {
        
        let loaded: ([EventTag]) -> Void = { [weak self] tags in
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
        let asCellViewModels: ([EventTag]) -> [EventTagCellViewModel] = { tags in
            let holidayTag = EventTagCellViewModel.holiday
            let defaultTag = EventTagCellViewModel.default
            let customCells = tags.map {
                EventTagCellViewModel(
                    id: .custom($0.uuid),
                    name: $0.name,
                    color: .custom(hex: $0.colorHex)
                )
            }
            return [holidayTag, defaultTag] + customCells
        }
        
        let applyOnOff: ([EventTagCellViewModel], Set<AllEventTagId>) -> [EventTagCellViewModel] = { cvms, offTagIdSet in
            
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
