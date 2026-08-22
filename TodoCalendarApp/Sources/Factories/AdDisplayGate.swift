//
//  AdDisplayGate.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class AdDisplayGate {

    private let subject = CurrentValueSubject<Bool, Never>(false)
    private var cancellable: AnyCancellable?

    // subject 초기값이 fail-closed 의 핵심 — 구독이 아직 아무 값도 안 흘렸을 때 광고가 나가면 안 된다
    init(userPlanConfirmationUsecase: any BillingUserPlanConfirmationUsecase) {
        self.cancellable = userPlanConfirmationUsecase.userPlanConfirmation
            .map { $0.isFreeConfirmed() }
            .removeDuplicates()
            .sink { [subject] isFree in
                subject.send(isFree)
            }
    }
}


extension AdDisplayGate {

    var canShowAd: AnyPublisher<Bool, Never> {
        return self.subject.removeDuplicates().eraseToAnyPublisher()
    }

    var canShowAdNow: Bool {
        return self.subject.value
    }
}
