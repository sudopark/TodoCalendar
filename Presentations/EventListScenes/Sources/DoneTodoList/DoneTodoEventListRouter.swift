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
        _ selected: @escaping (RemoveDoneTodoRange) -> Void
    )
}

// MARK: - Router

final class DoneTodoEventListRouter: BaseRouterImple, DoneTodoEventListRouting, @unchecked Sendable { 
    
    override func closeScene(animate: Bool, _ dismissed: (() -> Void)?) {
        self.currentScene?.dismiss(animated: true)
    }
}


extension DoneTodoEventListRouter {
    
    private var currentScene: (any DoneTodoEventListScene)? {
        self.scene as? (any DoneTodoEventListScene)
    }
    
    func showSelectRemoveDoneTodoRangePicker(
        _ selected: @escaping (RemoveDoneTodoRange) -> Void
    ) {
        Task { @MainActor in
         
            let actionSheet = UIAlertController(
                title: nil,
                message: "remove done todo history".localized(),
                preferredStyle: .actionSheet
            )
            RemoveDoneTodoRange.allCases.forEach { range in
                let action = UIAlertAction(title: range.buttonTitle, style: .default) { _ in
                    selected(range)
                }
                actionSheet.addAction(action)
            }
            actionSheet.addAction(
                UIAlertAction(title: "Cancel".localized(), style: .cancel)
            )
            self.currentScene?.present(actionSheet, animated: true)
        }
    }
}

private extension RemoveDoneTodoRange {
    
    var buttonTitle: String {
        switch self {
        case .all: return "all done todos".localized()
        case .olderThan1Month: return "older than 1 month"
        case .olderThan3Months: return "older than 3 months"
        case .olderThan6Months: return "older than 6 months"
        case .olderThan1Year: return "older than 1 year"
        }
    }
}