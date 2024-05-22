//
//  ResultTimelineEntry.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 5/19/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import WidgetKit


struct ResultTimelineEntry<T>: TimelineEntry {
    
    struct ErrorModel: Error {
        let error: any Error
        let message: String
        init(error: any Error, message: String? = nil) {
            self.error = error
            self.message = message ?? error.localizedDescription
        }
    }
    
    let date: Date
    let result: Result<T, ErrorModel>
    
    init(date: Date, result: Result<T, ErrorModel>) {
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
                ErrorModel(error: error)
            )
        }
    }
}


extension Date {
    
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
