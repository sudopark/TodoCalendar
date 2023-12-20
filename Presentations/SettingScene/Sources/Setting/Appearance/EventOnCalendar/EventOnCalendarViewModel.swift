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
    
    func prepare()
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
    init(uiSettingUsecase: any UISettingUsecase) {
        self.uiSettingUsecase = uiSettingUsecase
    }
    
    private enum Constant {
        static let maxFontSize: CGFloat = 7.0
        static let minFontSize: CGFloat = -2.0
    }
    
    private struct Subject {
        let setting = CurrentValueSubject<EventOnCalendarSetting?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}

extension EventOnCalendarViewModelImple {
    
    func prepare() {
        let setting = self.uiSettingUsecase.loadAppearanceSetting()
        self.subject.setting.send(setting.eventOnCalendar)
    }
    
    func increaseTextSize() {
        guard let setting = self.subject.setting.value,
              setting.textAdditionalSize < Constant.maxFontSize
        else { return }
        
        let newSetting = setting |> \.textAdditionalSize +~ 1
        self.updateSetting(newSetting)
    }
    
    func decreaseTextSize() {
        guard let setting = self.subject.setting.value,
              setting.textAdditionalSize > Constant.minFontSize
        else { return }
        let newSetting = setting |> \.textAdditionalSize -~ 1
        self.updateSetting(newSetting)
    }
    
    func toggleBoldText(_ isOn: Bool) {
        guard let setting = self.subject.setting.value,
              setting.bold != isOn
        else { return }
        let newSetting = setting |> \.bold .~ isOn
        self.updateSetting(newSetting)
    }
    
    func toggleShowEventTagColor(_ isOn: Bool) {
        guard let setting = self.subject.setting.value,
              setting.showEventTagColor != isOn
        else { return }
        let newSetting = setting |> \.showEventTagColor .~ isOn
        self.updateSetting(newSetting)
    }
    
    private func updateSetting(_ newEventOnCalendarSetting: EventOnCalendarSetting) {
        let params = EditAppearanceSettingParams()
            |> \.eventOnCalendar .~ newEventOnCalendarSetting
        do {
            let newSetting = try self.uiSettingUsecase.changeAppearanceSetting(params)
            self.subject.setting.send(newSetting.eventOnCalendar)
        } catch {
            // TODO: show error
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
            .compactMap { $0?.textAdditionalSize }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isBoldTextOnCalendar: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.bold }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var showEvnetTagColor: AnyPublisher<Bool, Never> {
        return self.subject.setting
            .compactMap { $0?.showEventTagColor }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
