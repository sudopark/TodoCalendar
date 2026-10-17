//
//  NextEventWidgetViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions
import CalendarPresentation


// MARK: - NextEventWidgetViewModel

public struct NextEventWidgetViewModel: Sendable {
    public let timeText: EventTimeText?
    public let eventTitle: String
    public var locationText: String?
    public var refreshAfter: Date?
    public var timeRawValue: EventTime?
    public var eventLink: URL?
    
    public init(
        timeText: EventTimeText?,
        eventTitle: String,
        refreshAfter: Date? = nil
    ) {
        self.timeText = timeText
        self.eventTitle = eventTitle
        self.refreshAfter = refreshAfter
    }
    
    public static var empty: Self {
        return .init(
            timeText: nil, eventTitle: "widget.next.noEvent".localized(), refreshAfter: nil
        )
    }
    
    public static var sample: Self {
        return .init(timeText: .init(text: "11:29"), eventTitle: "widget.next.sample".localized())
    }
}


// MARK: - NextEventListWidgetViewModel

public struct NextEventListWidgetViewModel: Sendable {
    public let models: [NextEventWidgetViewModel]
    public var refreshAfter: Date?

    public init(models: [NextEventWidgetViewModel], refreshAfter: Date? = nil) {
        self.models = models
        self.refreshAfter = refreshAfter
    }
    
    public static var empty: Self {
        return .init(models: [])
    }
    
    public static var sample: Self {
        return .init(models: [
            .init(timeText: .init(text: "10:00"), eventTitle: "widget.next.sample".localized()),
            .init(timeText: .init(text: "12:00"), eventTitle: "widget.weeks.sample::lunch".localized()),
            .init(timeText: .init(text: "16:30"), eventTitle: "widget.weeks.sample::call".localized())
        ])
    }
}
