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
    public var rowHeightOnCalendar: RowHeightOnCalendar = RowHeightOnCalendar.medium
    
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
        switch id ?? .default {
        case .holiday: return allEventTagColorMap[.holiday] ?? tagColors.holiday
        case .default: return allEventTagColorMap[.default] ?? tagColors.defaultColor
        default: return allEventTagColorMap[id ?? .default] ?? allEventTagColorMap[.default] ?? tagColors.defaultColor
        }
    }
    
    public func colorOnCalendar(
        _ id: EventTagId?, offColor: (ColorSet) -> UIColor = { _ in .clear }
    ) -> UIColor {
        guard self.eventOnCalendarShowEventTagColor
        else { return offColor(colorSet) }
        return self.color(id)
    }
    
    
    // Google calendar color
    public var googleCalendarColors: [String: GoogleCalendar.Colors] = [:]
    public private(set) var googleCalendarTagMap: [String: GoogleCalendar.Tag] = [:]

    public func applyCalendarTags(_ tags: [GoogleCalendar.Tag], for accountId: String) {
        googleCalendarTagMap = googleCalendarTagMap.filter { $0.value.ownerId != accountId }
        tags.forEach { googleCalendarTagMap[$0.id] = $0 }
    }

    public func clearCalendarTags(for accountId: String) {
        googleCalendarTagMap = googleCalendarTagMap.filter { $0.value.ownerId != accountId }
    }

    public func googleEventColor(
        _ colorId: String?, _ calendarId: String
    ) -> UIColor {
        let accountId = googleCalendarTagMap[calendarId]?.ownerId
        if let colorId {
            if let accountId {
                return googleCalendarColors[accountId]?.events[colorId]
                    .flatMap { UIColor.from(hex: $0.backgroudHex) } ?? .clear
            } else {
                // accountId를 특정할 수 없는 경우 전체 계정 순회 (위젯 등 레거시 경로)
                return googleCalendarColors.values.lazy
                    .compactMap { $0.events[colorId] }
                    .first
                    .flatMap { UIColor.from(hex: $0.backgroudHex) } ?? .clear
            }
        } else {
            let tag = googleCalendarTagMap[calendarId]
            let colorOnCalendar = tag?.backgroundColorHex.flatMap { UIColor.from(hex: $0) }
            let colorOnPalette = tag?.colorId
                .flatMap { paletteId in
                    if let accountId {
                        return googleCalendarColors[accountId]?.calendars[paletteId]
                    }
                    return googleCalendarColors.values.lazy.compactMap { $0.calendars[paletteId] }.first
                }
                .flatMap { UIColor.from(hex: $0.backgroudHex) }
            return colorOnCalendar ?? colorOnPalette ?? .clear
        }
    }
    
    public func googleEventColorOnCalendar(
        _ colorId: String?, _ calendarId: String,
        offColor: (ColorSet) -> UIColor = { _ in .clear }
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
        self.rowHeightOnCalendar = calendar.rowHeight
        
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
        case .large: return 75
        }
    }
}
