//
//  Scenes+Calendar.swift
//  Scenes
//
//  Created by sudo.park on 2023/07/30.
//

import Foundation
import Domain


// MARK: - CalendarScene

public protocol CalendarSceneInteractor: Sendable, AnyObject {
    
    func moveFocusToToday()
    func moveDay(_ day: CalendarDay, withClearPresented: Bool)
}

extension CalendarSceneInteractor {
    
    public func moveDay(_ day: CalendarDay) {
        self.moveDay(day, withClearPresented: false)
    }
}

public protocol CalendarSceneListener: Sendable, AnyObject {
    
    func calendarScene(focusChangedTo selected: SelectDayInfo)
}

public protocol CalendarScene: Scene where Interactor == any CalendarSceneInteractor {
    
    @MainActor
    func addChildMonths(_ monthScenes: [any Scene])
    
    @MainActor
    func changeFocus(at index: Int)
}


// MARK: - SelectDayDialogScene

public struct SelectDayInfo: Sendable, Equatable {
    public let dayInfo: CalendarDay
    public var year: Int { dayInfo.year }
    public var month: Int { dayInfo.month }
    public var day: Int { dayInfo.day }
    public let isCurrentYear: Bool
    public let isCurrentDay: Bool
    
    public init(
        _ year: Int, _ month: Int, _ day: Int,
        isCurrentYear: Bool,
        isCurrentDay: Bool
    ) {
        self.dayInfo = .init(year, month, day)
        self.isCurrentYear = isCurrentYear
        self.isCurrentDay = isCurrentDay
    }
}

public protocol SelectDayDialogSceneListener: Sendable, AnyObject {
    
    func daySelectDialog(didSelect day: SelectDayInfo)
}

public protocol SelectDayDialogScene: Scene where Interactor == EmptyInteractor { }


// MARK: - CalendarSceneBuilder

public protocol CalendarSceneBuilder {
    
    @MainActor
    func makeCalendarScene(
        listener: (any CalendarSceneListener)?
    ) -> any CalendarScene
    
    @MainActor
    func makeSelectDialog(
        current: CalendarDay,
        _ listener: (any SelectDayDialogSceneListener)?
    ) -> any SelectDayDialogScene
}

