//
//  
//  SelectEventRepeatOptionRouter.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol SelectEventRepeatOptionRouting: Routing, Sendable {
    
    func showRepeatingEndTimeIsInvalid(
        startDate: Date
    )
}

// MARK: - Router

final class SelectEventRepeatOptionRouter: BaseRouterImple, SelectEventRepeatOptionRouting, @unchecked Sendable { }


extension SelectEventRepeatOptionRouter {
    
    private var currentScene: (any SelectEventRepeatOptionScene)? {
        self.scene as? (any SelectEventRepeatOptionScene)
    }
    
    func showRepeatingEndTimeIsInvalid(
        startDate: Date
    ) {
        
        let startDateText = startDate.text("date_form:yyyy.MM_dd_hh:mm".localized())
        self.showToast(
            "eventDetail.repeating.endtime::shouldFutureThanStartTime".localized(with: startDateText)
        )
    }
}
