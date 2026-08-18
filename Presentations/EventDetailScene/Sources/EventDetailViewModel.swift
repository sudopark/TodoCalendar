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
import Scenes


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
    case copy
    case transformToSchedule
    case transformToTodo
    case addToTemplate  // 이후 구현 예정
    case toggleTo(isForemost: Bool)
    case toggleDDayCandidate(isRegistered: Bool)
    case toggleLiveActivity(isRegistered: Bool)
    case share
}

extension EventLiveActivityStartFailReason {

    var unavailableMessage: String {
        switch self {
        case .eventNotFound:
            return "calendar::event::more_action:live_activity:unavail::not_found".localized()
        case .alreadyPassed:
            return "calendar::event::more_action:live_activity:unavail::already_passed".localized()
        case .tooFarFuture:
            return "calendar::event::more_action:live_activity:unavail::too_far_future".localized()
        }
    }
}

extension Routing {

    /// 등록 불가는 오류가 아니라 안내다 — `showError`는 "문제가 발생했습니다" 뒤에 사유를
    /// 괄호로 덧붙여 안내문을 오류처럼 읽히게 한다.
    func showLiveActivityUnavailable(_ error: any Error) {
        guard let reason = error as? EventLiveActivityStartFailReason
        else { return self.showError(error) }

        let info = ConfirmDialogInfo()
            |> \.title .~ pure("calendar::event::more_action:live_activity:title".localized())
            |> \.message .~ pure(reason.unavailableMessage)
            |> \.withCancel .~ false
            |> \.confirmText .~ R.String.Common.close
        self.showConfirm(dialog: info)
    }
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
