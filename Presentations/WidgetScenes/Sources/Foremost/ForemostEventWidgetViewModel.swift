//
//  ForemostEventWidgetViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions
import CalendarPresentation


// MARK: - ForemostEventWidgetViewModel

public struct ForemostEventWidgetViewModel {
    
    public var eventModel: (any EventCellViewModel)?
    public let defaultTagColorSetting: DefaultEventTagColorSetting
    public var tag: CustomEventTag?
    public var widgetSetting = WidgetAppearanceSettings()

    public init(
        eventModel: (any EventCellViewModel)? = nil,
        defaultTagColorSetting: DefaultEventTagColorSetting,
        tag: CustomEventTag? = nil,
        widgetSetting: WidgetAppearanceSettings = WidgetAppearanceSettings()
    ) {
        self.eventModel = eventModel
        self.defaultTagColorSetting = defaultTagColorSetting
        self.tag = tag
        self.widgetSetting = widgetSetting
    }

    public static func sample() -> ForemostEventWidgetViewModel {
        
        let event = TodoEventCellViewModel("tood", name: "widget.events.foremost::sample::message".localized())
            |> \.periodText .~ .doubleText(
                .init(text: "calendar::event_time::todo".localized()), .init(text: "13:00")
            )
        let defaultTagColorSetting = DefaultEventTagColorSetting(
            holiday: "#D6236A", default: "#088CDA"
        )
        return .init(eventModel: event, defaultTagColorSetting: defaultTagColorSetting)
    }
}
