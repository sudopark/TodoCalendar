//
//  EventOnCalendarViewModel.swift
//  SettingScene
//
//  Created by sudo.park on 12/16/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes

struct EventOnCalendarAppearanceSetting {
    
    let eventOnCalenarTextAdditionalSize: CGFloat
    let eventOnCalendarIsBold: Bool
    let eventOnCalendarShowEventTagColor: Bool
    
    init(
        eventOnCalenarTextAdditionalSize: CGFloat,
        eventOnCalendarIsBold: Bool, 
        eventOnCalendarShowEventTagColor: Bool
    ) {
        self.eventOnCalenarTextAdditionalSize = eventOnCalenarTextAdditionalSize
        self.eventOnCalendarIsBold = eventOnCalendarIsBold
        self.eventOnCalendarShowEventTagColor = eventOnCalendarShowEventTagColor
    }
    
    init(_ setting: CalendarAppearanceSettings) {
        self.eventOnCalenarTextAdditionalSize = setting.eventOnCalenarTextAdditionalSize
        self.eventOnCalendarIsBold = setting.eventOnCalendarIsBold
        self.eventOnCalendarShowEventTagColor = setting.eventOnCalendarShowEventTagColor
    }
}

struct EventTextAdditionalSizeModel: Equatable {
    let sizeText: String
    var isIncreasable: Bool = true
    var isDescreasable: Bool = true
      
    init(_ size: CGFloat) {
        let prefix = size == 0 ? "±" : size < 0 ? "" : "+"
        self.sizeText = "\(prefix)\(Int(size))"
    }
}

protocol EventOnCalendarViewModel: AnyObject, Sendable {
    
    func increaseTextSize()
    func decreaseTextSize()
    func toggleBoldText(_ isOn: Bool)
    func toggleShowEventTagColor(_ isOn: Bool)
    
    var textIncreasedSizeText: AnyPublisher<EventTextAdditionalSizeModel, Never> { get }
    var isBoldTextOnCalendar: AnyPublisher<Bool, Never> { get }
    var showEvnetTagColor: AnyPublisher<Bool, Never> { get }
}

final class EventOnCalendarViewModelImple: EventOnCalendarViewModel, @unchecked Sendable {
    
    private let uiSettingUsecase: any UISettingUsecase
    weak var router: (any EventOnCalendarViewRouting)?
    init(
        setting: EventOnCalendarAppearanceSetting,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.subject.setting.send(setting)
    }
    
    private enum Constant {
        static let maxFontSize: CGFloat = 7.0
        static let minFontSize: CGFloat = -2.0
    }
    
    private struct Subject {
        let setting = CurrentValueSubject<EventOnCalendarAppearanceSetting?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}

extension EventOnCalendarViewModelImple {
    
    func increaseTextSize() {
        guard let setting = self.subject.setting.value,
              setting.eventOnCalenarTextAdditionalSize < Constant.maxFontSize
        else { return }
        
        let params = EditCalendarAppearanceSettingParams() |> \.eventOnCalenarTextAdditionalSize .~ (setting.eventOnCalenarTextAdditionalSize + 1)
        self.updateSetting(params)
    }
    
    func decreaseTextSize() {
        guard let setting = self.subject.setting.value,
              setting.eventOnCalenarTextAdditionalSize > Constant.minFontSize
        else { return }

        let params = EditCalendarAppearanceSettingParams() |> \.eventOnCalenarTextAdditionalSize .~ (setting.eventOnCalenarTextAdditionalSize - 1)
        self.updateSetting(params)
    }
    
    func toggleBoldText(_ isOn: Bool) {
        guard let setting = self.subject.setting.value,
              setting.eventOnCalendarIsBold != isOn
        else { return }
        let params = EditCalendarAppearanceSettingParams() |> \.eventOnCalendarIsBold .~ isOn
        self.updateSetting(params)
    }
    
    func toggleShowEventTagColor(_ isOn: Bool) {
        guard let setting = self.subject.setting.value,
              setting.eventOnCalendarShowEventTagColor != isOn
        else { return }
        let params = EditCalendarAppearanceSettingParams() |> \.eventOnCalendarShowEventTagColor .~ isOn
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

extension EventOnCalendarViewModelImple {
    
    var textIncreasedSizeText: AnyPublisher<EventTextAdditionalSizeModel, Never> {
        let transform: (CGFloat) -> EventTextAdditionalSizeModel = { size in
            return EventTextAdditionalSizeModel(size)
                |> \.isIncreasable .~ (size < Constant.maxFontSize)
                |> \.isDescreasable .~ (size > Constant.minFontSize)
        }
        return self.subject.setting
            .compactMap { $0?.eventOnCalenarTextAdditionalSize }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isBoldTextOnCalendar: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.eventOnCalendarIsBold }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var showEvnetTagColor: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.eventOnCalendarShowEventTagColor }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
