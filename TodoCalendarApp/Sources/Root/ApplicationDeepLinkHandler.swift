//
//  ApplicationDeepLinkHandler.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 12/28/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Scenes
import CalendarScenes
import Extensions


final class ApplicationDeepLinkHandlerImple: @unchecked Sendable {
    
    weak var appRouter: (any ApplicationRouting)?
    private weak var calendarHandler: (any DeepLinkHandler)?
    private var pendingCalendarLink: PendingDeepLink?
    // 위젯 핸들러는 화면 트리 밖이라 여기서 붙잡지 않으면 곧바로 해제된다
    private var widgetHandler: (any DeepLinkHandler)?
    private var pendingWidgetLink: PendingDeepLink?
    
    init() { }
}

extension ApplicationDeepLinkHandlerImple {
    
    func attach(calendarHandler: any DeepLinkHandler) {
        self.calendarHandler = calendarHandler
        guard let pending = self.pendingCalendarLink else { return }
        self.pendingCalendarLink = nil
        _ = calendarHandler.handleLink(pending)
    }
    
    func attach(widgetHandler: any DeepLinkHandler) {
        self.widgetHandler = widgetHandler
        guard let pending = self.pendingWidgetLink else { return }
        self.pendingWidgetLink = nil
        _ = widgetHandler.handleLink(pending)
    }
    
    func handleLink(_ url: URL) -> Bool {
        
        guard let link = PendingDeepLink(url),
              link.scheme == AppDeepLink.scheme
        else {
            return false
        }
        
        let handleResult: DeepLinkHandleResult = {
            switch link.host {
            case "calendar":
                guard let handler = self.calendarHandler
                else {
                    self.pendingCalendarLink = link
                    return .handle
                }
                return handler.handleLink(link)
                
            case "widget":
                guard let handler = self.widgetHandler
                else {
                    self.pendingWidgetLink = link
                    return .handle
                }
                return handler.handleLink(link)
                
            default:
                return .needUpdate
            }
        }()
        
        if handleResult == .needUpdate {
            self.showIsNeedAppUpdate()
        }
        
        return true
    }
    
    private func showIsNeedAppUpdate() {
        
        let confirmed: () -> Void = { [weak self] in
            self?.appRouter?.openSafari(AppEnvironment.appstoreLinkPath)
        }
        
        let info = ConfirmDialogInfo()
            |> \.title .~ "common.info".localized()
            |> \.message .~ "deeplink::invalid_link_message".localized()
            |> \.confirmText .~ "common.update".localized()
            |> \.confirmed .~ confirmed
            |> \.withCancel .~ true
            |> \.cancelText .~ "common.cancel"
        
        self.appRouter?.showConfirm(dialog: info)
    }
}
