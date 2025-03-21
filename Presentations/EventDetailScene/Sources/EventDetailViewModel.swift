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
import Extensions


struct EventDetailTypeModel: Equatable {
    
    enum SelectionType {
        case todo
        case schedule
        case holiday
    }
    
    var selectType: SelectionType
    let isTogglable: Bool
    let text: String
    var showHelpButton: Bool = false

    
    static func makeCase(_ isTodo: Bool) -> EventDetailTypeModel {
        return EventDetailTypeModel(
            selectType: isTodo ? .todo : .schedule,
            isTogglable: true,
            text: "eventDetail.edit::make::case".localized(),
            showHelpButton: false
        )
    }
    
    static func todoCase() -> EventDetailTypeModel {
        return EventDetailTypeModel(
            selectType: .todo,
            isTogglable: false,
            text: "eventDetail.edit::todo::case".localized(),
            showHelpButton: true
        )
    }
    
    static func scheduleCase() -> EventDetailTypeModel {
        return EventDetailTypeModel(
            selectType: .schedule,
            isTogglable: false,
            text: "eventDetail.edit::schedule::case".localized(),
            showHelpButton: true
        )
    }
    
    static func holidayCase(_ country: String) -> EventDetailTypeModel {
        let text = "eventDetail.edit::holiday::case".localized(with: country)
        return EventDetailTypeModel(
            selectType: .holiday,
            isTogglable: false,
            text: text,
            showHelpButton: false
        )
    }
}

enum EventDetailMoreAction: Equatable {
    case remove(onlyThisEvent: Bool)
    case copy   // 이후 구현 예정
    case addToTemplate  // 이후 구현 예정
    case toggleTo(isForemost: Bool)
    case share
}

protocol EventDetailViewModel: Sendable, AnyObject {
    
    var router: (any EventDetailRouting)? { get set }
    
    func attachInput()
    func prepare()
    func handleMoreAction(_ action: EventDetailMoreAction)
    func close()
    func toggleIsTodo()
    func showTodoGuide()
    func showForemostEventGuide()
    func save()
    
    // presenter
    var isForemost: AnyPublisher<Bool, Never> { get }
    var isLoading: AnyPublisher<Bool, Never> { get }
    var eventDetailTypeModel: AnyPublisher<EventDetailTypeModel, Never> { get }
    var hasChanges: AnyPublisher<Bool, Never> { get }
    var isSavable: AnyPublisher<Bool, Never> { get }
    var isSaving: AnyPublisher<Bool, Never> { get }
    var moreActions: AnyPublisher<[[EventDetailMoreAction]], Never> { get }
}
