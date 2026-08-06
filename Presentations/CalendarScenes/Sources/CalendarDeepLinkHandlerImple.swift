//
//  CalendarDeepLinkHandlerImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 12/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Scenes


public final class CalendarDeepLinkHandlerImple: DeepLinkHandler, @unchecked Sendable {
    
    private weak var eventHandler: (any DeepLinkHandler)?
    private weak var calendarInteractor: (any CalendarSceneInteractor)?
    private var pendingEventLink: PendingDeepLink?
    private var pendingSelectCalendar: [String: String]?
    private var pendingAIEntry: Bool = false
    
    public init() { }
}


extension CalendarDeepLinkHandlerImple {
    
    func attach(eventHandler: any DeepLinkHandler) {
        self.eventHandler = eventHandler
        guard let pending = self.pendingEventLink else { return }
        self.pendingEventLink = nil
        _ = eventHandler.handleLink(pending)
    }
    
    // 날짜 이동을 먼저 끝낸 뒤 AI 입력을 띄운다 — 순서가 반대면 입력이 뜬 상태에서 뒤늦게 달력이 움직인다.
    func attach(calendarInteractor: any CalendarSceneInteractor) {
        self.calendarInteractor = calendarInteractor

        if let pending = self.pendingSelectCalendar {
            self.pendingSelectCalendar = nil
            _ = self.handleMoveDate(calendarInteractor, pending)
        }

        guard self.pendingAIEntry else { return }
        self.pendingAIEntry = false
        calendarInteractor.requestAIEntry()
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

        case "ai":
            guard let interactor = self.calendarInteractor
            else {
                self.pendingAIEntry = true
                return .handle
            }
            interactor.requestAIEntry()
            return .handle

        case nil:
            guard let interactor = self.calendarInteractor
            else {
                self.pendingSelectCalendar = link.queryParams
                return .handle
            }
            return self.handleMoveDate(interactor, link.queryParams)
            
        default:
            return .needUpdate
        }
    }
    
    private func handleMoveDate(
        _ calendarInteractor: any CalendarSceneInteractor, _ queries: [String: String]
    ) -> DeepLinkHandleResult {
        guard
            let select = queries["select"],
            case let components = select.components(separatedBy: "_"),
            let year = components[safe: 0].flatMap ({ Int($0) }),
            let month = components[safe: 1].flatMap ({ Int($0) })
        else { return .needUpdate }
        
        let day = components[safe: 2].flatMap { Int($0) } ?? 1
        let calendarDay = CalendarDay(year, month, day)
        calendarInteractor.moveDay(calendarDay, withClearPresented: true)
        return .handle
    }
}
