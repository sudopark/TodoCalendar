//
//  LiveActivityToggleHandling.swift
//  EventDetailScene
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Scenes
import Extensions


struct LiveActivityActionModel: Equatable {

    let isRegistered: Bool

    var itemText: String {
        return self.isRegistered
            ? "calendar::event::more_action:live_activity:unregister:item_name".localized()
            : "calendar::event::more_action:live_activity:register:item_name".localized()
    }
}


protocol LiveActivityToggleHandling: AnyObject, Sendable {

    var eventLiveActivityUsecase: any EventLiveActivityUsecase { get }
    var liveActivityRouting: (any Routing)? { get }
}

extension LiveActivityToggleHandling {

    func startOrStopLiveActivity(_ target: LiveActivityTarget, isRegistered: Bool) {
        Task { [weak self] in
            guard let self else { return }
            guard isRegistered == false
            else { return await self.eventLiveActivityUsecase.stopActivity() }

            do {
                try await self.eventLiveActivityUsecase.startActivity(target)
            } catch {
                self.liveActivityRouting?.showLiveActivityUnavailable(error)
            }
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


private extension EventLiveActivityStartFailReason {

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
