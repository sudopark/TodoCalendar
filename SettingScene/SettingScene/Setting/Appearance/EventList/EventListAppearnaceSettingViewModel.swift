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


protocol EventListAppearnaceSettingViewModel: AnyObject, Sendable {
    
    func prepare()
    func increaseFontSize()
    func decreaseFontSize()
    func toggleShowHolidayName(_ show: Bool)
    func toggleShowLunarCalendarDate(_ show: Bool)
    func toggleIsShowTimeWith24HourForm(_ isOn: Bool)
    func toggleDimOnPastEvent(_ isOn: Bool)
    
    var eventFontIncreasedSizeModel: AnyPublisher<EventTextAdditionalSizeModel, Never> { get }
    var isShowHolidayName: AnyPublisher<Bool, Never> { get }
    var isShowLunarCalendarDate: AnyPublisher<Bool, Never> { get }
    var isShowTimeWith24HourForm: AnyPublisher<Bool, Never> { get }
    var isDimOnPastEvent: AnyPublisher<Bool, Never> { get }
}

final class EventListAppearnaceSettingViewModelImple: EventListAppearnaceSettingViewModel, @unchecked Sendable {
    
    private enum Constants {
        static let maxFontSize: CGFloat = 4
        static let minFontSize: CGFloat = -4
    }
    
    private let uiSettingUsecase: any UISettingUsecase
    init(uiSettingUsecase: any UISettingUsecase) {
        self.uiSettingUsecase = uiSettingUsecase
    }
    
    private struct Subject {
        let setting = CurrentValueSubject<EventListSetting?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}


extension EventListAppearnaceSettingViewModelImple {
    
    func prepare() {
        let setting = self.uiSettingUsecase.loadAppearanceSetting()
        self.subject.setting.send(setting.eventList)
    }
    
    func increaseFontSize() {
        guard let setting = self.subject.setting.value,
              setting.textAdditionalSize < Constants.maxFontSize
        else { return }
        
        let newSetting = setting |> \.textAdditionalSize +~ 1
        self.updateSetting(newSetting)
    }
    
    func decreaseFontSize() {
        guard let setting = self.subject.setting.value,
              setting.textAdditionalSize > Constants.minFontSize
        else { return }
        
        let newSetting = setting |> \.textAdditionalSize -~ 1
        self.updateSetting(newSetting)
    }
    
    func toggleShowHolidayName(_ show: Bool) {
        guard let setting = self.subject.setting.value,
              setting.showHoliday != show
        else { return }
        
        let newSetting = setting |> \.showHoliday .~ show
        self.updateSetting(newSetting)
    }
    
    func toggleShowLunarCalendarDate(_ show: Bool) {
        guard let setting = self.subject.setting.value,
              setting.showLunarCalendarDate != show
        else { return }
        
        let newSetting = setting |> \.showLunarCalendarDate .~ show
        self.updateSetting(newSetting)
    }
    
    func toggleIsShowTimeWith24HourForm(_ isOn: Bool) {
        guard let setting = self.subject.setting.value,
              setting.is24hourForm != isOn
        else { return }
        
        let newSetting = setting |> \.is24hourForm .~ isOn
        self.updateSetting(newSetting)
    }
    
    func toggleDimOnPastEvent(_ isOn: Bool) {
        guard let setting = self.subject.setting.value,
              setting.dimOnPastEvent != isOn
        else { return }
        
        let newSetting = setting |> \.dimOnPastEvent .~ isOn
        self.updateSetting(newSetting)
    }
    
    private func updateSetting(_ newEventListSetting: EventListSetting) {
        let params = EditAppearanceSettingParams()
            |> \.eventList .~ newEventListSetting
        
        do {
            let newSetting = try self.uiSettingUsecase.changeAppearanceSetting(params)
            self.subject.setting.send(newSetting.eventList)
        } catch {
            // TODO: show error
        }
    }
}

extension EventListAppearnaceSettingViewModelImple {
    
    var eventFontIncreasedSizeModel: AnyPublisher<EventTextAdditionalSizeModel, Never> {
        let transform: (CGFloat) -> EventTextAdditionalSizeModel = { size in
            return EventTextAdditionalSizeModel(size)
                |> \.isIncreasable .~ (size < Constants.maxFontSize)
                |> \.isDescreasable .~ (size > Constants.minFontSize)
        }
        return self.subject.setting
            .compactMap { $0?.textAdditionalSize }
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
    
    var isDimOnPastEvent: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.dimOnPastEvent }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
