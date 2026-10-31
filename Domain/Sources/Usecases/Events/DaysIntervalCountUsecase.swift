//
//  DaysIntervalCountUsecase.swift
//  Domain
//
//  Created by sudo.park on 10/20/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics


public protocol DaysIntervalCountUsecase: Sendable {
    
    func countDays(to eventTime: EventTime) -> AnyPublisher<Int, Never>
    func countDays(to holiday: Holiday) -> AnyPublisher<Int, Never>
}

extension DaysIntervalCountUsecase {
    
    public func countDays(to date: Date) -> AnyPublisher<Int, Never> {
        return self.countDays(to: .at(date.timeIntervalSince1970))
    }
}

public final class DaysIntervalCountUsecaseImple: DaysIntervalCountUsecase, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    public init(calendarSettingUsecase: any CalendarSettingUsecase) {
        self.calendarSettingUsecase = calendarSettingUsecase
    }
}


extension DaysIntervalCountUsecaseImple {
    
    public func countDays(
        to eventTime: EventTime
    ) -> AnyPublisher<Int, Never> {
        return self.countInterval { timeZone in
            return Date(
                timeIntervalSince1970: eventTime.rangeWithShifttingifNeed(on: timeZone).lowerBound
            )
        }
    }
    
    public func countDays(
        to holiday: Holiday
    ) -> AnyPublisher<Int, Never> {
        return self.countInterval { timeZone in
            return holiday.date(at: timeZone)
        }
    }
    
    private func countInterval(
        _ selectToDate: @escaping (TimeZone) -> Date?
    ) -> AnyPublisher<Int, Never> {
        
        let transform: (Date, TimeZone, Bool) -> Int? = { fromDate, timeZone, countsTargetDayAsOne in
            guard let toDate = selectToDate(timeZone) else { return nil }
            let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
            return calendar.ddayInterval(fromDate, toDate, countsTargetDayAsOne: countsTargetDayAsOne)
        }
     
        return Publishers.CombineLatest3(
            self.secondTicks,
            self.calendarSettingUsecase.currentTimeZone,
            self.calendarSettingUsecase.ddayCountsTargetDayAsOne
        )
        .compactMap(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    private var secondTicks: AnyPublisher<Date, Never> {
        return Timer
            .publish(every: 1.0, on: .main, in: .common).autoconnect()
            .map { _ in Date() }
            .prepend(Date())
            .eraseToAnyPublisher()
    }
}
