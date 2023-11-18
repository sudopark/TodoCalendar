//
//  EventDetailViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/1/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


struct EventDetailTypeModel: Equatable {
    
    enum TogglableIsTodoOrSchedule {
        case todo
        case schedule
    }
    
    var isTodoOrSchedule: TogglableIsTodoOrSchedule?
    let text: String
    var showHelpButton: Bool = false

    static func makeCase(_ isTodo: Bool) -> EventDetailTypeModel {
        return EventDetailTypeModel(
            isTodoOrSchedule: isTodo ? .todo : .schedule, text: "Todo event".localized(), 
            showHelpButton: false
        )
    }
    
    static func todoCase() -> EventDetailTypeModel {
        return EventDetailTypeModel(
            isTodoOrSchedule: nil, text: "Todo event".localized(), 
            showHelpButton: true
        )
    }
    
    static func scheduleCase() -> EventDetailTypeModel {
        return EventDetailTypeModel(
            isTodoOrSchedule: nil, text: "Schedule event".localized(), 
            showHelpButton: true
        )
    }
    
    static func holidayCase(_ country: String) -> EventDetailTypeModel {
        let text = "Public Holiday in %@".localized(with: country)
        return EventDetailTypeModel(
            isTodoOrSchedule: nil, text: text, 
            showHelpButton: false
        )
    }
}

enum EventDetailMoreAction: Equatable {
    case remove(onlyThisEvent: Bool)
    case copy
    case addToTemplate
    case share
}

protocol EventDetailViewModel: Sendable, AnyObject {
    
    var router: (any EventDetailRouting)? { get set }
    
    func attachInput()
    func prepare()
    func handleMoreAction(_ action: EventDetailMoreAction)
    func close()
    func toggleIsTodo()
    func save()
    
    // presenter
    var isLoading: AnyPublisher<Bool, Never> { get }
    var eventDetailTypeModel: AnyPublisher<EventDetailTypeModel, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
    var moreActions: AnyPublisher<[[EventDetailMoreAction]], Never> { get }
}
