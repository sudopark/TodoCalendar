//
//  LoggerConsoleBuilder.swift
//  Extensions
//
//  Created by sudo.park on 2023/09/21.
//

import SwiftUI
import PulseUI

public struct LoggerConsoleBuilder {
    
    public init() { }
    
    @MainActor
    public func makeConsoleView() -> UIViewController {
        let viewController = UIHostingController(rootView: ConsoleView())
        viewController.extendedLayoutIncludesOpaqueBars = true
        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }
}
