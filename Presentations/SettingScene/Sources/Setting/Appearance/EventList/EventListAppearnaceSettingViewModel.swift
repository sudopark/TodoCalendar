//
//  EventListAppearnaceSettingViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 12/16/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain


struct EventListAppearanceSetting {
    
    let eventTextAdditionalSize: CGFloat
    let showHoliday: Bool
    let showLunarCalendarDate: Bool
    let is24hourForm: Bool
    
    init(
        eventTextAdditionalSize: CGFloat,
        showHoliday: Bool,
        showLunarCalendarDate: Bool,
        is24hourForm: Bool, 
        dimOnPastEvent: Bool
    ) {
        self.eventTextAdditionalSize = eventTextAdditionalSize
        self.showHoliday = showHoliday
        self.showLunarCalendarDate = showLunarCalendarDate
        self.is24hourForm = is24hourForm
    }
    
    init(_ setting: CalendarAppearanceSettings) {
        self.eventTextAdditionalSize = setting.eventTextAdditionalSize
        self.showHoliday = setting.showHoliday
        self.showLunarCalendarDate = setting.showLunarCalendarDate
        self.is24hourForm = setting.is24hourForm
    }
}


struct EventListAppearanceSampleModel: Equatable {
    
    let dateText: String
    var is24HourForm: Bool = true
    var holidayName: String?
    var lunarDateText: String?
    
    init?(_ setting: EventListAppearanceSetting) {
        let calendar = Calendar(identifier: .gregorian)
        guard let christmas = calendar.dateBySetting(from: Date(), mutating: { $0.month = 12; $0.day = 25 })
        else { return nil }
        
        let form = DateFormatter() |> \.dateFormat .~ "date_form::yyyy_MM_dd_E_".localized()
        self.dateText = form.string(from: christmas)
        self.is24HourForm = setting.is24hourForm
        if setting.showHoliday {
            self.holidayName = "setting.appearance.event.sample::christmas".localized()
        }
        
        if setting.showLunarCalendarDate {
            let lunarForm = DateFormatter() 
                |> \.dateFormat .~ "date_form::MM_dd".localized()
                |> \.calendar .~ Calendar(identifier: .chinese)
            self.lunarDateText = lunarForm.string(from: christmas)
        }
    }
}

protocol EventListAppearnaceSettingViewModel: AnyObject, Sendable {
    
    func increaseFontSize()
    func decreaseFontSize()
    func toggleShowHolidayName(_ show: Bool)
    func toggleShowLunarCalendarDate(_ show: Bool)
    func toggleIsShowTimeWith24HourForm(_ isOn: Bool)
    
    var eventListSamepleModel: AnyPublisher<EventListAppearanceSampleModel, Never> { get }
    var eventFontIncreasedSizeModel: AnyPublisher<EventTextAdditionalSizeModel, Never> { get }
    var isShowHolidayName: AnyPublisher<Bool, Never> { get }
    var isShowLunarCalendarDate: AnyPublisher<Bool, Never> { get }
    var isShowTimeWith24HourForm: AnyPublisher<Bool, Never> { get }
}

final class EventListAppearnaceSettingViewModelImple: EventListAppearnaceSettingViewModel, @unchecked Sendable {
    
    private enum Constants {
        static let maxFontSize: CGFloat = 4
        static let minFontSize: CGFloat = -4
    }
    
    private let uiSettingUsecase: any UISettingUsecase
    weak var router: (any EventListAppearnaceSettingViewRouting)?
    init(
        setting: EventListAppearanceSetting,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.subject.setting.send(setting)
    }
    
    private struct Subject {
        let setting = CurrentValueSubject<EventListAppearanceSetting?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}


extension EventListAppearnaceSettingViewModelImple {
    
    func increaseFontSize() {
        guard let setting = self.subject.setting.value,
              setting.eventTextAdditionalSize < Constants.maxFontSize
        else { return }
        
        let params = EditCalendarAppearanceSettingParams() |> \.eventTextAdditionalSize .~ (setting.eventTextAdditionalSize + 1)
        self.updateSetting(params)
    }
    
    func decreaseFontSize() {
        guard let setting = self.subject.setting.value,
              setting.eventTextAdditionalSize > Constants.minFontSize
        else { return }
        
        let params = EditCalendarAppearanceSettingParams() |> \.eventTextAdditionalSize .~ (setting.eventTextAdditionalSize - 1)
        self.updateSetting(params)
    }
    
    func toggleShowHolidayName(_ show: Bool) {
        guard let setting = self.subject.setting.value,
              setting.showHoliday != show
        else { return }
        
        let params = EditCalendarAppearanceSettingParams() |> \.showHoliday .~ show
        self.updateSetting(params)
    }
    
    func toggleShowLunarCalendarDate(_ show: Bool) {
        guard let setting = self.subject.setting.value,
              setting.showLunarCalendarDate != show
        else { return }
        
        let params = EditCalendarAppearanceSettingParams() |> \.showLunarCalendarDate .~ show
        self.updateSetting(params)
    }
    
    func toggleIsShowTimeWith24HourForm(_ isOn: Bool) {
        guard let setting = self.subject.setting.value,
              setting.is24hourForm != isOn
        else { return }
        
        let params = EditCalendarAppearanceSettingParams() |> \.is24hourForm .~ isOn
        self.updateSetting(params)
    }
    
    private func updateSetting(_ params: EditCalendarAppearanceSettingParams) {
        
        do {
            let newSetting = try self.uiSettingUsecase.changeCalendarAppearanceSetting(params)
            self.subject.setting.send(.init(newSetting))
        } catch {
            self.router?.showError(error)
        }
    }
}

extension EventListAppearnaceSettingViewModelImple {
    
    var eventListSamepleModel: AnyPublisher<EventListAppearanceSampleModel, Never> {
        return self.subject.setting
            .compactMap { $0 }
            .compactMap { EventListAppearanceSampleModel($0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var eventFontIncreasedSizeModel: AnyPublisher<EventTextAdditionalSizeModel, Never> {
        let transform: (CGFloat) -> EventTextAdditionalSizeModel = { size in
            return EventTextAdditionalSizeModel(size)
                |> \.isIncreasable .~ (size < Constants.maxFontSize)
                |> \.isDescreasable .~ (size > Constants.minFontSize)
        }
        return self.subject.setting
            .compactMap { $0?.eventTextAdditionalSize }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isShowHolidayName: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.showHoliday }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isShowLunarCalendarDate: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.showLunarCalendarDate }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isShowTimeWith24HourForm: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.is24hourForm }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
