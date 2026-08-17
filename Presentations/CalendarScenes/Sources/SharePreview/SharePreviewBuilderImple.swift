//
//  SharePreviewBuilderImple.swift
//  CalendarScenes
//
//  Created by sudo.park on 8/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Domain
import Scenes
import CommonPresentation


// MARK: - SharePreviewSceneBuilerImple

final class SharePreviewSceneBuilerImple: @unchecked Sendable {

    private let usecaseFactory: any UsecaseFactory
    private let viewAppearance: ViewAppearance

    init(
        usecaseFactory: any UsecaseFactory,
        viewAppearance: ViewAppearance
    ) {
        self.usecaseFactory = usecaseFactory
        self.viewAppearance = viewAppearance
    }
}


extension SharePreviewSceneBuilerImple: SharePreviewSceneBuilder {

    @MainActor
    func makeSharePreviewScene(
        range: Range<TimeInterval>, kind: CalendarShareRangeKind
    ) -> any SharePreviewScene {
        let calendarSettingUsecase = self.usecaseFactory.makeCalendarSettingUsecase()
        let uiSettingUsecase = self.usecaseFactory.makeUISettingUsecase()
        let eventTagUsecase = self.usecaseFactory.makeEventTagUsecase()
        let googleCalendarUsecase = self.usecaseFactory.makeGoogleCalendarUsecase()
        let appleCalendarUsecase = self.usecaseFactory.makeAppleCalendarUsecase()
        let calendarUsecase = self.usecaseFactory.makeCalendarUsecase()
        let eventListUsecase = CalendarEventListhUsecaseImple(
            todoUsecase: self.usecaseFactory.makeTodoEventUsecase(),
            scheduleUsecase: self.usecaseFactory.makeScheduleEventUsecase(),
            googleCalendarUsecase: googleCalendarUsecase,
            appleCalendarUsecase: appleCalendarUsecase,
            foremostEventUsecase: self.usecaseFactory.makeForemostEventUsecase(),
            calendarSettingUsecase: calendarSettingUsecase,
            eventTagUsecase: eventTagUsecase,
            uiSettingUsecase: uiSettingUsecase
        )
        let viewModel = SharePreviewViewModelImple(
            range: range,
            kind: kind,
            eventListUsecase: eventListUsecase,
            calendarSettingUsecase: calendarSettingUsecase,
            uiSettingUsecase: uiSettingUsecase,
            eventTagUsecase: eventTagUsecase,
            eventShareSettingUsecase: self.usecaseFactory.makeEventShareSettingUsecase(),
            googleCalendarUsecase: googleCalendarUsecase,
            appleCalendarUsecase: appleCalendarUsecase,
            calendarUsecase: calendarUsecase
        )
        let router = SharePreviewRouter()
        viewModel.router = router
        let viewController = SharePreviewViewController(
            viewModel: viewModel,
            viewAppearance: self.viewAppearance
        )
        router.scene = viewController
        return viewController
    }
}
