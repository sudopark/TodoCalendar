//
//  
//  DoneTodoEventListRouter.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol DoneTodoEventListRouting: Routing, Sendable { 
    
    func showSelectRemoveDoneTodoRangePicker(
        _ selected: @Sendable @escaping (RemoveDoneTodoRange) -> Void
    )
}

// MARK: - Router

final class DoneTodoEventListRouter: BaseRouterImple, DoneTodoEventListRouting, @unchecked Sendable {
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        Task { @MainActor in
            self.currentScene?.dismiss(animated: true)
        }
    }
}


extension DoneTodoEventListRouter {
    
    private var currentScene: (any DoneTodoEventListScene)? {
        self.scene as? (any DoneTodoEventListScene)
    }
    
    func showSelectRemoveDoneTodoRangePicker(
        _ selected: @Sendable @escaping (RemoveDoneTodoRange) -> Void
    ) {
        Task { @MainActor in
         
            let actionSheet = UIAlertController(
                title: nil,
                message: "eventList::remove::confirm::message".localized(),
                preferredStyle: .actionSheet
            )
            RemoveDoneTodoRange.allCases.forEach { range in
                let action = UIAlertAction(title: range.buttonTitle, style: .default) { _ in
                    selected(range)
                }
                actionSheet.addAction(action)
            }
            actionSheet.addAction(
                UIAlertAction(title: "common.cancel".localized(), style: .cancel)
            )
            self.currentScene?.present(actionSheet, animated: true)
        }
    }
}

private extension RemoveDoneTodoRange {
    
    var buttonTitle: String {
        switch self {
        case .all: return "eventList::remove::confirm::button::all".localized()
        case .olderThan1Month: return "eventList::remove::confirm::button::olderThan1m".localized()
        case .olderThan3Months: return "eventList::remove::confirm::button::olderThan3m".localized()
        case .olderThan6Months: return "eventList::remove::confirm::button::olderThan6m".localized()
        case .olderThan1Year: return "eventList::remove::confirm::button::olderThan1y".localized()
        }
    }
}
