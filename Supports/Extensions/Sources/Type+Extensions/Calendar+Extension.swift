//
//  Calendar+extension.swift
//  Extensions
//
//  Created by sudo.park on 2023/04/16.
//

import Foundation
import Prelude
import Optics


extension Calendar {
    
    public func year(of date: Date) -> Int? {
        return self.dateComponents([.year], from: date).year
    }
    
    public func month(of date: Date) -> Int? {
        return self.dateComponents([.month], from: date).month
    }
    
    public func day(of date: Date) -> Int? {
        return self.dateComponents([.day], from: date).day
    }
    
    public func addDays(_ interval: Int, from: Date) -> Date? {
        return self.date(byAdding: .day, value: interval, to: from)
    }
    
    public func addMonth(_ interval: Int, from: Date) -> Date? {
        return self.date(byAdding: .month, value: interval, to: from)
    }
    
    public func addYear(_ interval: Int, from: Date) -> Date? {
        return self.date(byAdding: .year, value: interval, to: from)
    }
    
    public func firstDayOfMonth(from date: Date) -> Date? {
        return self.date(from: self.dateComponents([.year, .month], from: self.startOfDay(for: date)))
    }
    
    public func endOfDay(for date: Date) -> Date? {
        return self.startOfDay(for: date)
            .add(days: 1)
            .map { $0.addingTimeInterval(-1) }
    }
    
    public func lastDayOfMonth(from date: Date) -> Date? {
        return self.firstDayOfMonth(from: date)
            .flatMap { self.date(byAdding: DateComponents(month: 1, day: -1), to: $0) }
    }
    
    public func lastOfSameWeekDay(_ from: Date) -> Date? {
        guard let weekDay = self.dateComponents([.weekday], from: from).weekday,
              let lastDayOfMonth = self.lastDayOfMonth(from: from),
              let lastDayOfMonthWeekDay = self.dateComponents([.weekday], from: lastDayOfMonth).weekday
        else { return nil }
       
        let lastDayOfMonthComponents = self.dateComponents([.year, .month, .day], from: lastDayOfMonth)
        guard let lastDayOfMonthDay = lastDayOfMonthComponents.day else { return nil }
        
        let daysToMinus = (lastDayOfMonthWeekDay - weekDay + 7) % 7
        let newComponents = self.dateComponents([.year, .month, .day, .hour, .minute, .second], from: from)
            |> \.day .~ (lastDayOfMonthDay - daysToMinus)
        
        return self.date(from: newComponents)
    }
    
    public func first(day: Int, from date: Date) -> Date? {
        guard let firstDayOfMonth = self.firstDayOfMonth(from: date),
              let firstDayWeekDay = self.dateComponents([.weekday], from: firstDayOfMonth).weekday
        else { return nil }
        let daysToAdd = (day + 7 - firstDayWeekDay) % 7
        let newComponents = self.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            |> \.day .~ (1 + daysToAdd)
        return self.date(from: newComponents)
    }
    
    public func syncTimes(_ originDate: Date, with date: Date) -> Date? {
        let components = self.dateComponents([.hour, .minute, .second], from: date)
        guard let hour = components.hour,
              let minute = components.minute,
              let second = components.second
        else { return nil }
        return self.date(bySettingHour: hour, minute: minute, second: second, of: originDate)
    }
    
    public func dateBySetting(from date: Date, mutating: (inout DateComponents) -> Void) -> Date? {
        var components = self.dateComponents(in: self.timeZone, from: date)
        components.yearForWeekOfYear = nil
        mutating(&components)
        return self.date(from: components)
    }
}



extension Calendar {

    private func dayIdentifier(_ date: Date) -> String {
        let (year, month, day) = (
            self.component(.year, from: date),
            self.component(.month, from: date),
            self.component(.day, from: date)
        )
        return "\(year)-\(month)-\(day)"
    }
    
    public func daysIdentifiers(_ range: Range<TimeInterval>) -> [String] {
        guard let lastDateOfEnd = self.endOfDay(for: .init(timeIntervalSince1970: range.upperBound))
        else { return [] }
        var cursor = Date(timeIntervalSince1970: range.lowerBound)
        var sender: [String] = []
        while self.compare(cursor, to: lastDateOfEnd, toGranularity: .day) != .orderedDescending {
            sender.append(self.dayIdentifier(cursor))
            
            cursor = cursor.addingTimeInterval(24 * 3600)
        }
        return sender
    }
}
