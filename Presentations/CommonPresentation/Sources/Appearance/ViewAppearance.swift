//
//  ViewAppearance.swift
//  CommonPresentation
//
//  Created by sudo.park on 2023/08/05.
//

import SwiftUI
import Combine
import Domain
@preconcurrency import CombineExt

@Observable public class ViewAppearance: @unchecked Sendable {
    
    @ObservationIgnored public var colorSetKey: ColorSetKeys
    public var tagColors: EventTagColorSet
    public var colorSet: any ColorSet
    public var fontSet: any FontSet
    public var navigationBarId: String = UUID().uuidString
    public func forceReloadNavigationBar() {
        self.navigationBarId = UUID().uuidString
    }
    
    // calendar
    public var accnetDayPolicy: [AccentDays: Bool]
    public var showUnderLineOnEventDay: Bool
    public var rowHeightOnCalendar: CGFloat = RowHeightOnCalendar.medium.cgValue
    
    // event on calendar
    public var eventOnCalenarTextAdditionalSize: CGFloat
    public var eventOnCalendarIsBold: Bool
    public var eventOnCalendarShowEventTagColor: Bool
    
    // event list
    public var eventTextAdditionalSize: CGFloat
    public var showHoliday: Bool
    public var showLunarCalendarDate: Bool
    public var is24hourForm: Bool
    
    // general
    public var hapticEffectOff: Bool
    public var animationEffectOff: Bool
    
    // event tag color
    public var allEventTagColorMap: [EventTagId: UIColor] = [:]
    public func color(_ id: EventTagId?) -> UIColor {
        return allEventTagColorMap[id ?? .default] ??  allEventTagColorMap[.default] ?? .clear
    }
    
    public func colorOnCalendar(_ id: EventTagId?) -> UIColor {
        guard self.eventOnCalendarShowEventTagColor
        else { return .clear }
        return self.color(id)
    }
    
    
    // Google calendar color
    public var googleCalendarColor: GoogleCalendar.Colors?
    public var googleCalendarTagMap: [String: GoogleCalendar.Tag] = [:]
    
    public func googleEventColor(
        _ colorId: String?, _ calendarId: String
    ) -> UIColor {
        
        if let colorId {
            return self.googleCalendarColor?.events[colorId]
                .flatMap { UIColor.from(hex: $0.backgroudHex) } ?? .clear
        } else {
            let colorOnCalendar = self.googleCalendarTagMap[calendarId]
                .flatMap { $0.backgroundColorHex }
                .flatMap { UIColor.from(hex: $0) }
            let colorOnPalette = self.googleCalendarTagMap[calendarId]
                .flatMap { $0.colorId }
                .flatMap { self.googleCalendarColor?.calendars[$0] }
                .flatMap { UIColor.from(hex: $0.backgroudHex) }
            return colorOnCalendar ?? colorOnPalette ?? .clear
        }
    }
    
    public func googleEventColorOnCalendar(
        _ colorId: String?, _ calendarId: String
    ) -> UIColor {
        guard self.eventOnCalendarShowEventTagColor
        else { return .clear }
        return googleEventColor(colorId, calendarId)
    }
    
    public init(setting: AppearanceSettings, isSystemDarkTheme: Bool) {
        
        let (calendar, defaultTagColor) = (setting.calendar, setting.defaultTagColor)
        
        self.tagColors = .init(
            holiday: UIColor.from(hex: defaultTagColor.holiday) ?? .clear,
            defaultColor: UIColor.from(hex: defaultTagColor.default) ?? .clear
        )
        self.colorSetKey = calendar.colorSetKey
        self.colorSet = calendar.colorSetKey.convert(isSystemDarkTheme: isSystemDarkTheme)
        self.fontSet = calendar.fontSetKey.convert()
        
        self.accnetDayPolicy = calendar.accnetDayPolicy
        self.showUnderLineOnEventDay = calendar.showUnderLineOnEventDay
        self.rowHeightOnCalendar = calendar.rowHeight.cgValue
        
        self.eventOnCalenarTextAdditionalSize = calendar.eventOnCalenarTextAdditionalSize
        self.eventOnCalendarIsBold = calendar.eventOnCalendarIsBold
        self.eventOnCalendarShowEventTagColor = calendar.eventOnCalendarShowEventTagColor
        
        self.eventTextAdditionalSize = calendar.eventTextAdditionalSize
        self.showHoliday = calendar.showHoliday
        self.showLunarCalendarDate = calendar.showLunarCalendarDate
        self.is24hourForm = calendar.is24hourForm
        
        self.hapticEffectOff = calendar.hapticEffectIsOn
        self.animationEffectOff = calendar.animationEffectIsOn
    }
    
    public func updateEventColorMap(by allEventTags: [any EventTag]) {
        self.allEventTagColorMap = allEventTags.reduce(into: [EventTagId: UIColor]()) { acc, tag in
            acc[tag.tagId] = tag.colorHex.flatMap { UIColor.from(hex: $0) }
        }
    }
}

// MARK: - combined property

extension ViewAppearance {
    
    public func accentCalendarDayColor(_ accent: AccentDays?) -> UIColor {
        switch accent {
        case .holiday:
            return self.accnetDayPolicy[.holiday] == true ? self.colorSet.holidayOrWeekEndWithAccent : self.colorSet.holidayText
        case .sunday:
            return self.accnetDayPolicy[.sunday] == true ? self.colorSet.holidayOrWeekEndWithAccent : self.colorSet.weekEndText
        case .saturday:
            return self.accnetDayPolicy[.saturday] == true ? self.colorSet.holidayOrWeekEndWithAccent : self.colorSet.weekEndText
        default:
            return self.colorSet.weekDayText
        }
    }
    
    public func eventTextFontOnCalendar() -> UIFont {
        let defaultSize: CGFloat = 10
        return UIFont.systemFont(
            ofSize: defaultSize + self.eventOnCalenarTextAdditionalSize,
            weight: self.eventOnCalendarIsBold ? .semibold : .regular
        )
    }
    
    public func eventTextFontOnList(isForemost: Bool = false) -> UIFont {
        let defaultSize: CGFloat = 14
        return UIFont.systemFont(
            ofSize: defaultSize + self.eventTextAdditionalSize,
            weight: isForemost ? .bold : .regular
        )
    }
    
    public func eventSubNormalTextFontOnList() -> UIFont {
        let defaultSize: CGFloat = 12
        return UIFont.systemFont(
            ofSize: defaultSize + self.eventTextAdditionalSize,
            weight: .regular
        )
    }
    
    @MainActor
    public func impactIfNeed(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        guard self.hapticEffectOff else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    public func withAnimationIfNeed<R>(
        _ animation: Animation? = .default,
        _ body: () throws -> R
    ) rethrows -> R {
        guard animationEffectOff == false
        else {
            return try body()
        }
        return try withAnimation(animation, body)
    }
}

extension ViewAppearance {
    
    public var didUpdated: AnyPublisher<(EventTagColorSet, any FontSet, any ColorSet), Never> {
        Publishers.Create { subscriber in
            
            final class IsCancelledFlag: @unchecked Sendable {
                var flag = false
            }
            let isCancelled = IsCancelledFlag()
            
            @Sendable func track() {
                guard isCancelled.flag == false else { return }
                
                Task { @MainActor in
                    guard isCancelled.flag == false else { return }
                    
                    let current = withObservationTracking {
                        return (self.tagColors, self.fontSet, self.colorSet)
                    } onChange: {
                        guard isCancelled.flag == false else { return }
                        
                        DispatchQueue.main.async {
                            track()
                        }
                    }
                    
                    subscriber.send(current)
                }
            }
            track()
            
            return AnyCancellable {
                isCancelled.flag = true
            }
        }
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }
}

extension ColorSetKeys {
    
    public func convert(isSystemDarkTheme: Bool) -> any ColorSet {
        switch self {
        case .systemTheme where isSystemDarkTheme:
            return DefaultDarkColorSet()
        case .systemTheme:
            return DefaultLightColorSet()
        case .defaultLight:
            return DefaultLightColorSet()
        case .defaultDark:
            return DefaultDarkColorSet()
        }
    }
}

extension FontSetKeys {
    
    public func convert() -> any FontSet {
        switch self {
        case .systemDefault: return SystemDefaultFontSet()
        }
    }
}

extension RowHeightOnCalendar {
    
    public var cgValue: CGFloat {
        switch self {
        case .small: return 45
        case .medium: return 75
        case .large: return 125
        }
    }
}
