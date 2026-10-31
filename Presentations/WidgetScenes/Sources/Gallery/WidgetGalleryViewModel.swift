//
//  WidgetGalleryViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import WidgetKit
import Prelude
import Optics
import Domain
import Extensions
import Scenes


protocol WidgetGalleryViewModel: AnyObject, WidgetGallerySceneInteractor {

    func refresh()
    func selectItem(_ itemId: String)
    func selectSystemTheme()
    func selectCustomBackground(hex: String)
    func toggleDDayCountsTargetDayAsOne(_ newValue: Bool)
    func close()

    var items: AnyPublisher<[WidgetGalleryItem], Never> { get }
    var setting: AnyPublisher<WidgetAppearanceSettings, Never> { get }
    var defaultStyles: AnyPublisher<[String: WidgetStyle], Never> { get }
    var ddayCountsTargetDayAsOne: AnyPublisher<Bool, Never> { get }
}

final class WidgetGalleryViewModelImple: WidgetGalleryViewModel, @unchecked Sendable {

    private let uiSettingUsecase: any UISettingUsecase
    private let widgetStyleUsecase: any WidgetStyleUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    var router: (any WidgetGalleryRouting)?

    init(
        setting: WidgetAppearanceSettings,
        uiSettingUsecase: any UISettingUsecase,
        widgetStyleUsecase: any WidgetStyleUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.widgetStyleUsecase = widgetStyleUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.subject.setting.send(setting)
    }

    private struct Subject {
        let setting = CurrentValueSubject<WidgetAppearanceSettings?, Never>(nil)
    }
    private let subject = Subject()
}


// MARK: - handle events

extension WidgetGalleryViewModelImple {

    func refresh() {
        self.customizableVariants.forEach {
            self.widgetStyleUsecase.refreshStyles(of: $0)
        }
    }

    func selectItem(_ itemId: String) {
        guard let item = self.availableItems.first(where: { $0.id == itemId }),
              let setting = self.subject.setting.value
        else { return }
        self.router?.routeToDetail(item, setting: setting)
    }

    func selectSystemTheme() {
        let params = EditWidgetAppearanceSettingParams()
            |> \.background .~ .system
        self.change(params)
    }

    func selectCustomBackground(hex: String) {
        let params = EditWidgetAppearanceSettingParams()
            |> \.background .~ .custom(hex: hex)
        self.change(params)
    }

    private func change(_ params: EditWidgetAppearanceSettingParams) {
        do {
            let newSetting = try self.uiSettingUsecase.changeWidgetAppearanceSetting(params)
            self.subject.setting.send(newSetting)
        } catch {
            self.router?.showError(error)
        }
    }

    func toggleDDayCountsTargetDayAsOne(_ newValue: Bool) {
        self.calendarSettingUsecase.updateDDayCountsTargetDayAsOne(newValue)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetVariant.ddaySmall.kind)
    }

    func close() {
        self.router?.closeScene()
    }
}


// MARK: - outputs

extension WidgetGalleryViewModelImple {

    private var availableItems: [WidgetGalleryItem] {
        return WidgetGalleryItem.allCases
    }

    private var customizableVariants: [WidgetVariant] {
        return self.availableItems
            .flatMap { $0.variants }
            .filter { $0.isCustomizable }
    }

    var items: AnyPublisher<[WidgetGalleryItem], Never> {
        return Just(self.availableItems).eraseToAnyPublisher()
    }

    var setting: AnyPublisher<WidgetAppearanceSettings, Never> {
        return self.subject.setting
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var ddayCountsTargetDayAsOne: AnyPublisher<Bool, Never> {
        return self.calendarSettingUsecase.ddayCountsTargetDayAsOne
    }

    var defaultStyles: AnyPublisher<[String: WidgetStyle], Never> {
        let entryStreams = self.customizableVariants.map { variant in
            return self.widgetStyleUsecase.styles(of: variant)
                .compactMap { $0.first }
                .map { [variant.id: $0] }
                .eraseToAnyPublisher()
        }
        return Publishers.MergeMany(entryStreams)
            .scan([String: WidgetStyle]()) { styles, entry in
                return styles.merging(entry) { _, newStyle in newStyle }
            }
            .eraseToAnyPublisher()
    }
}
