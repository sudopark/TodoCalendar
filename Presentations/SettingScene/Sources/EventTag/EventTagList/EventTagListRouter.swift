//
//  
//  EventTagListRouter.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//

import UIKit
import Scenes
import CommonPresentation


// MARK: - Routing

protocol EventTagListRouting: Routing, Sendable { 
    
    func routeToAddNewTag(listener: EventTagDetailSceneListener)
    
    func routeToEditTag(
        _ tagInfo: OriginalTagInfo,
        listener: EventTagDetailSceneListener
    )
    
    func routeToEventSetting()
}

// MARK: - Router

final class EventTagListRouter: BaseRouterImple, EventTagListRouting, @unchecked Sendable { 
    
    private let hasNavigation: Bool
    private let eventSettingSceneBuilder: any EventSettingSceneBuiler
    private let tagDetailSceneBuilder: any EventTagDetailSceneBuiler
    init(
        hasNavigation: Bool,
        eventSettingSceneBuilder: any EventSettingSceneBuiler,
        tagDetailSceneBuilder: any EventTagDetailSceneBuiler
    ) {
        self.hasNavigation = hasNavigation
        self.eventSettingSceneBuilder = eventSettingSceneBuilder
        self.tagDetailSceneBuilder = tagDetailSceneBuilder
    }
    
    override func closeScene(animate: Bool, _ dismissed: (@Sendable () -> Void)?) {
        Task { @MainActor in
            if let navigation = self.currentScene?.navigationController {
                navigation.popViewController(animated: animate)
                dismissed?()
            } else {
                self.currentScene?.dismiss(animated: animate, completion: dismissed)
            }
        }
    }
}


extension EventTagListRouter {
    
    private var currentScene: (any EventTagListScene)? {
        self.scene as? (any EventTagListScene)
    }
    
    // TODO: router implememnts
    func routeToAddNewTag(listener: EventTagDetailSceneListener) {
        Task { @MainActor in
            let nextScene = self.tagDetailSceneBuilder.makeEventTagDetailScene(
                originalInfo: nil,
                listener: listener
            )
            self.currentScene?.present(nextScene, animated: true)
        }
    }
    
    func routeToEditTag(
        _ tagInfo: OriginalTagInfo,
        listener: EventTagDetailSceneListener
    ) {
        Task { @MainActor in
            let nextScene = self.tagDetailSceneBuilder.makeEventTagDetailScene(
                originalInfo: tagInfo,
                listener: listener
            )
            self.currentScene?.present(nextScene, animated: true)
        }
    }
    
    func routeToEventSetting() {
        
        Task { @MainActor in
            let nextScene = self.eventSettingSceneBuilder.makeEventSettingScene()
        
            if self.hasNavigation {
                // navigation 있는 케이스: 이벤트 상세 - 태그 선택 - 모든 태그 보기
                self.currentScene?.navigationController?.pushViewController(nextScene, animated: true)
            } else {
                // navigation 없는 케이스: 메인화면 - 이벤트 리스트 바로 진입
                self.currentScene?.present(nextScene, animated: true)
            }
        }
    }
}
