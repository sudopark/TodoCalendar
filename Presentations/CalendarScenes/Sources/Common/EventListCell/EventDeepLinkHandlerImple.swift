//
//  EventDeepLinkHandlerImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 12/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Scenes


protocol EventDeepLinkHandler: DeepLinkHandler {
    
    func attach(router: (any EventListCellEventHanleRouting)?)
}

final class EventDeepLinkHandlerImple: EventDeepLinkHandler, @unchecked Sendable {
    
    private weak var router: (any EventListCellEventHanleRouting)?
    private var isReadyToHandle: Bool = false
    init() { }
    
    private enum SupportPath: String {
        case todo
        case schedule
        case holiday
        case google
    }
    
    private var pendingPathAndLink: (SupportPath, PendingDeepLink)?
}

extension EventDeepLinkHandlerImple {
    
    func attach(router: (any EventListCellEventHanleRouting)?) {
        self.router = router
        self.isReadyToHandle = true
        
        guard let (path, link) = self.pendingPathAndLink else { return }
        self.pendingPathAndLink = nil
        self.handle(path, pending: link)
    }
    
    func handleLink(_ link: PendingDeepLink) -> DeepLinkHandleResult {
        var link = link
        let firstPath = link.removeFirstPath().flatMap { SupportPath(rawValue: $0) }
        
        guard let firstPath
        else { return .needUpdate }
        
        guard isReadyToHandle
        else {
            self.pendingPathAndLink = (firstPath, link)
            return .handle
        }
        
        self.handle(firstPath, pending: link)
        return .handle
    }
    
    private func handle(_ path: SupportPath, pending: PendingDeepLink) {
        
        self.router?.dismissPresented(animated: false) { [weak self] in
         
            switch path {
            case .todo:
                guard let eventId = pending.queryParams["event_id"] else
                { return }
                self?.router?.routeToTodoEventDetail(eventId)
            
            case .schedule:
                guard let eventId = pending.queryParams["event_id"],
                      let time = EventTime(deepLink: pending.queryParams)
                else { return }
                self?.router?.routeToScheduleEventDetail(eventId, time)
                
            case .holiday:
                guard let eventId = pending.queryParams["event_id"] else
                { return }
                self?.router?.routeToHolidayEventDetail(eventId)
                
            case .google:
                guard let eventId = pending.queryParams["event_id"],
                      let calendarId = pending.queryParams["calendar_id"] else
                { return }
                
                self?.router?.routeToGoogleEventDetail(calendarId: calendarId, eventId: eventId)
            }
        }
    }
}
