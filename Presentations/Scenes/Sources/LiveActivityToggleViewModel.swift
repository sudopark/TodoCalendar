//
//  LiveActivityToggleViewModel.swift
//  Scenes
//
//  Created by sudo.park on 8/19/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation


public protocol LiveActivityToggleViewModel: AnyObject, Sendable {

    func startOrStopLiveActivity(_ target: LiveActivityTarget, isCurrentlyRegistered: Bool)
    var registeredTarget: AnyPublisher<LiveActivityTarget?, Never> { get }
}

public final class LiveActivityToggleViewModelImple: LiveActivityToggleViewModel, @unchecked Sendable {

    private let eventLiveActivityUsecase: any EventLiveActivityUsecase
    public weak var router: (any Routing)?

    public init(eventLiveActivityUsecase: any EventLiveActivityUsecase) {
        self.eventLiveActivityUsecase = eventLiveActivityUsecase
    }

    public func startOrStopLiveActivity(_ target: LiveActivityTarget, isCurrentlyRegistered: Bool) {
        Task { [weak self] in
            guard let self else { return }
            guard isCurrentlyRegistered == false
            else { return await self.eventLiveActivityUsecase.stopActivity() }

            do {
                try await self.eventLiveActivityUsecase.startActivity(target)
                self.router?.showToast(
                    "calendar::event::more_action:live_activity:register:success".localized()
                )
            } catch {
                self.router?.showLiveActivityUnavailable(error)
            }
        }
    }

    public var registeredTarget: AnyPublisher<LiveActivityTarget?, Never> {
        return self.eventLiveActivityUsecase.registeredTarget
    }
}


extension Routing {

    /// 등록 불가는 오류가 아니라 안내다 — `showError`는 "문제가 발생했습니다" 뒤에 사유를
    /// 괄호로 덧붙여 안내문을 오류처럼 읽히게 한다.
    public func showLiveActivityUnavailable(_ error: any Error) {
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
