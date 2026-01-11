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
    let weekRowHeight: RowHeightOnCalendar
    
    init(
        eventOnCalenarTextAdditionalSize: CGFloat,
        eventOnCalendarIsBold: Bool, 
        eventOnCalendarShowEventTagColor: Bool,
        weekRowHeight: RowHeightOnCalendar
    ) {
        self.eventOnCalenarTextAdditionalSize = eventOnCalenarTextAdditionalSize
        self.eventOnCalendarIsBold = eventOnCalendarIsBold
        self.eventOnCalendarShowEventTagColor = eventOnCalendarShowEventTagColor
        self.weekRowHeight = weekRowHeight
    }
    
    init(_ setting: CalendarAppearanceSettings) {
        self.eventOnCalenarTextAdditionalSize = setting.eventOnCalenarTextAdditionalSize
        self.eventOnCalendarIsBold = setting.eventOnCalendarIsBold
        self.eventOnCalendarShowEventTagColor = setting.eventOnCalendarShowEventTagColor
        self.weekRowHeight = setting.rowHeight
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

struct RowHeightOnCalendarViewModel: Identifiable, Hashable {
    let height: RowHeightOnCalendar
    let text: String
    
    var id: RowHeightOnCalendar { self.height }
    
    init(_ height: RowHeightOnCalendar) {
        self.height = height
        switch height {
        case .small:
            self.text = "setting.appearance.day_row_height::small::text".localized()
        case .medium:
            self.text = "setting.appearance.day_row_height::medium::text".localized()
        case .large:
            self.text = "setting.appearance.day_row_height::large::text".localized()
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(height)
    }
}

protocol EventOnCalendarViewModel: AnyObject, Sendable {
    
    func selectRowHeightOnCalendar(_ height: RowHeightOnCalendar)
    func increaseTextSize()
    func decreaseTextSize()
    func toggleBoldText(_ isOn: Bool)
    func toggleShowEventTagColor(_ isOn: Bool)
    
    var rowHeight: AnyPublisher<RowHeightOnCalendarViewModel, Never> { get }
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
    
    func selectRowHeightOnCalendar(_ height: RowHeightOnCalendar) {
        guard let setting = self.subject.setting.value,
              setting.weekRowHeight != height
        else { return }
        
        let params = EditCalendarAppearanceSettingParams()
            |> \.rowHeight .~ height
        self.updateSetting(params)
    }
    
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
    
    var rowHeight: AnyPublisher<RowHeightOnCalendarViewModel, Never> {
        
        return self.subject.setting
            .compactMap { $0?.weekRowHeight }
            .map { RowHeightOnCalendarViewModel($0) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
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
