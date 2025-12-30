//
//  CalendarDeepLinkHandlerImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 12/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Scenes


public final class CalendarDeepLinkHandlerImple: DeepLinkHandler, @unchecked Sendable {
    
    private weak var eventHandler: (any DeepLinkHandler)?
    private var pendingEventLink: PendingDeepLink?
    
    public init() { }
}


extension CalendarDeepLinkHandlerImple {
    
    func attach(eventHandler: any DeepLinkHandler) {
        self.eventHandler = eventHandler
        guard let pending = self.pendingEventLink else { return }
        self.pendingEventLink = nil
        _ = eventHandler.handleLink(pending)
    }
    
    public func handleLink(_ link: PendingDeepLink) -> DeepLinkHandleResult {
        var link = link
        
        let firstPath = link.removeFirstPath()
        switch firstPath {
        case "event":
            guard let handler = self.eventHandler
            else {
                self.pendingEventLink = link
                return .handle
            }
            return handler.handleLink(link)
            
        default:
            return .needUpdate
        }
    }
}
