//
//  CalendarSectionAppearnaceSettingViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 12/3/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes

struct CalendarSectionAppearanceSetting {
    
    let accnetDayPolicy: [AccentDays: Bool]
    let showUnderLineOnEventDay: Bool
    
    init(
        accnetDayPolicy: [AccentDays : Bool],
        showUnderLineOnEventDay: Bool
    ) {
        self.accnetDayPolicy = accnetDayPolicy
        self.showUnderLineOnEventDay = showUnderLineOnEventDay
    }
    
    init(_ setting: CalendarAppearanceSettings) {
        self.accnetDayPolicy = setting.accnetDayPolicy
        self.showUnderLineOnEventDay = setting.showUnderLineOnEventDay
    }
}

struct CalendarAppearanceModel: Equatable {
    
    struct DayModel: Equatable {
        let number: Int
        let hasEvent: Bool
        let accent: AccentDays?
        
        init(
            _ number: Int,
            hasEvent: Bool = false,
            accent: AccentDays? = nil
        ) {
            self.number = number
            self.hasEvent = hasEvent
            self.accent = accent
        }
    }
    
    let weekDays: [DayOfWeeks]
    let weeks: [[DayModel?]]
    
    init(
        _ weekDays: [DayOfWeeks],
        _ weeks: [[DayModel?]]
    ) {
        self.weekDays = weekDays
        self.weeks = weeks
    }
    
    init(_ startOfWeek: DayOfWeeks) {
        let total: [DayOfWeeks] = [
            .sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday
        ]
        // 1, 0, 6, 5, 4, 3, 2
        let startIndex = total.firstIndex(of: startOfWeek)!
        
        self.weekDays = (startIndex..<startIndex+7).map {
            return total[$0 % 7]
        }
        
        let wednesDayIndex = weekDays.firstIndex(of: .wednesday)!
        
        // 1일은 월요일, 31일은 수요일
        let monthStartPaddingDays = (7 - startIndex + 1) % 7
        let monthEndPaddingDays = 7 - wednesDayIndex - 1
        
        let totalDaysSize = monthStartPaddingDays + 31 + monthEndPaddingDays
        
        let hasEventDays: Set<Int> = [2, 4, 5, 14, 17, 22, 23, 30]
        self.weeks = (0..<totalDaysSize/7).map { weekIndex in
            return (0..<7).map { dayIndex -> DayModel? in
                let index = (weekIndex * 7 + dayIndex) - monthStartPaddingDays
                let dayNumber = index + 1
                guard (1...31) ~= dayNumber else { return nil }

                let isSunday = dayNumber % 7 == 0; let isSaturday = dayNumber % 7 == 6
                let isHoliday = dayNumber == 13 || dayNumber == 24
                let accent: AccentDays? = isSunday ? .sunday : isSaturday ? .saturday : isHoliday ? .holiday : nil
                return DayModel(
                    dayNumber,
                    hasEvent: hasEventDays.contains(dayNumber),
                    accent: accent
                )
            }
        }
    }
}


protocol CalendarSectionAppearnaceSettingViewModel: AnyObject, Sendable {
    
    func changeStartOfWeekDay(_ day: DayOfWeeks)
    func toggleAccentDay(_ type: AccentDays)
    func changeColorTheme()
    func changeWidgetTheme()
    func toggleIsShowUnderLineOnEventDay(_ newValue: Bool)
    
 
    var currentWeekStartDay: AnyPublisher<DayOfWeeks, Never> { get }
    var calendarAppearanceModel: AnyPublisher<CalendarAppearanceModel, Never> { get }
    var accentDaysActivatedMap: AnyPublisher<[AccentDays: Bool], Never> { get }
    var selectedColorTheme: AnyPublisher<ColorThemeModel, Never> { get }
    var isShowUnderLineOnEventDay: AnyPublisher<Bool, Never> { get }
}

protocol CalendarSectionRouting: Routing {
    
    func routeToSelectColorTheme()
    func routeToChangeWidgetTheme(_ setting: WidgetAppearanceSettings)
}

final class CalendarSectionViewModelImple: CalendarSectionAppearnaceSettingViewModel, @unchecked Sendable {
    
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let uiSettingUsecase: any UISettingUsecase
    weak var router: CalendarSectionRouting?
    
    init(
        setting: CalendarSectionAppearanceSetting,
        calendarSettingUsecase: any CalendarSettingUsecase,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.calendarSettingUsecase = calendarSettingUsecase
        self.uiSettingUsecase = uiSettingUsecase
        self.subject.setting.send(setting)
        
        self.internalBind()
    }
    
    private struct Subject {
        let startWeekDay = CurrentValueSubject<DayOfWeeks?, Never>(nil)
        let setting = CurrentValueSubject<CalendarSectionAppearanceSetting?, Never>(nil)
    }
    private let subject = Subject()
    private var cancelables: Set<AnyCancellable> = []
    
    private func internalBind() {
        
        self.calendarSettingUsecase.firstWeekDay
            .sink(receiveValue: { [weak self] day in
                self?.subject.startWeekDay.send(day)
            })
            .store(in: &self.cancelables)
    }
}


extension CalendarSectionViewModelImple {
    
    func changeStartOfWeekDay(_ day: DayOfWeeks) {
        // TOOD: remove duplicated
        guard self.subject.startWeekDay.value != day else { return }
        self.calendarSettingUsecase.updateFirstWeekDay(day)
    }
    
    func changeWidgetTheme() {
        let setting = self.uiSettingUsecase.loadSavedAppearanceSetting()
        self.router?.routeToChangeWidgetTheme(setting.widget)
    }
    
    func changeColorTheme() {
        self.router?.routeToSelectColorTheme()
    }
    
    func toggleAccentDay(_ type: AccentDays) {
        guard let origin = self.subject.setting.value
        else { return }
        let newMap = origin.accnetDayPolicy
            |> key(type) %~ { !($0 ?? false) }
        
        let params = EditCalendarAppearanceSettingParams()
            |> \.accnetDayPolicy .~ newMap
        do {
            let newSetting = try self.uiSettingUsecase.changeCalendarAppearanceSetting(params)
            self.subject.setting.send(.init(newSetting))
        } catch {
            self.router?.showError(error)
        }
    }
    
    func toggleIsShowUnderLineOnEventDay(_ newValue: Bool) {
        guard let origin = self.subject.setting.value,
              origin.showUnderLineOnEventDay != newValue
        else { return }
        
        let params = EditCalendarAppearanceSettingParams()
            |> \.showUnderLineOnEventDay .~ newValue
        
        do {
            let newSetting = try self.uiSettingUsecase.changeCalendarAppearanceSetting(params)
            self.subject.setting.send(.init(newSetting))
        } catch {
            self.router?.showError(error)
        }
    }
}


extension CalendarSectionViewModelImple {
    
    var currentWeekStartDay: AnyPublisher<DayOfWeeks, Never> {
        return self.subject.startWeekDay
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var calendarAppearanceModel: AnyPublisher<CalendarAppearanceModel, Never> {
        return self.subject.startWeekDay
            .compactMap { $0 }
            .compactMap { CalendarAppearanceModel($0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var accentDaysActivatedMap: AnyPublisher<[AccentDays: Bool], Never> {
        return self.subject.setting
            .compactMap { $0?.accnetDayPolicy }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedColorTheme: AnyPublisher<ColorThemeModel, Never> {
        return self.uiSettingUsecase.currentCalendarUISeting
            .map { ColorThemeModel($0.colorSetKey) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isShowUnderLineOnEventDay: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.showUnderLineOnEventDay }
            .eraseToAnyPublisher()
    }
}
