//
//  ResultTimelineEntry.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/19/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit
import Domain
import CommonPresentation
import Extensions

struct WidgetErrorModel: Error {
    let error: any Error
    let message: String
    let reason: String?
    init(error: any Error, message: String? = nil) {
        self.error = error
        self.message = message ?? "widget.fail.message".localized()
        self.reason = "\(error)"
    }
}

struct ResultTimelineEntry<T>: TimelineEntry {
    
    let date: Date
    let result: Result<T, WidgetErrorModel>
    var background: WidgetAppearanceSettings.Background = .system
    
    init(date: Date, result: Result<T, WidgetErrorModel>) {
        self.date = date
        self.result = result
    }
    
    init(date: Date, result: () throws -> T) {
        self.date = date
        do {
            let model = try result()
            self.result = .success(model)
        } catch {
            self.result = .failure(
                WidgetErrorModel(error: error)
            )
        }
    }
    
    var backgroundShape: some ShapeStyle {
        switch self.background {
        case .system:
            return AnyShapeStyle(.background)
        case .custom(let hex):
            guard let color = UIColor.from(hex: hex)
            else {
                return AnyShapeStyle(.background)
            }
            let isLight = color.isLight
            let colors: any ColorSet = isLight ? DefaultLightColorSet() : DefaultDarkColorSet()
            return AnyShapeStyle(
                color.asColor.gradient.shadow(
                    .drop(
                        color: colors.text0.withAlphaComponent(0.4).asColor,
                        radius: 10
                    )
                )
            )
        }
        
    }
}


extension Date {
    
    // TODO: 다음 업데이트 시간은 유저가 설정한 timeZone에 따라 다르게 구현할 필요가 있음
    var nextUpdateTime: Date {
        let calendar = Calendar(identifier: .gregorian)
        let nextHour = self.addingTimeInterval(3600)
        guard let nextDayTime = calendar.date(byAdding: .day, value: 1, to: self)
        else {
            return nextHour
        }
        let nextDayStartTime = calendar.startOfDay(for: nextDayTime)
        let interval = nextDayStartTime.timeIntervalSince(self)
        return interval < 3600 ? nextDayStartTime : nextHour
    }
}


extension WidgetAppearanceSettings.Background {
    
    func colorSet(_ systemIsLight: Bool) -> any ColorSet {
        let isLight = switch self {
            case .system: systemIsLight
            case .custom(let hex): UIColor.from(hex: hex)?.isLight ?? systemIsLight
        }
        return isLight ? DefaultLightColorSet() : DefaultDarkColorSet()
    }
}
