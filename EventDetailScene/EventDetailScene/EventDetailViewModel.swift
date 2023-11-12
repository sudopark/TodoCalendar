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
    var isTodo: AnyPublisher<Bool, Never> { get }
    var isTodoOrScheduleTogglable: Bool { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
    var moreActions: AnyPublisher<[[EventDetailMoreAction]], Never> { get }
}
