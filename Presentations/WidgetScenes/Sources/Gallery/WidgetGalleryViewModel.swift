//
//  WidgetGalleryViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
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
    func close()

    var items: AnyPublisher<[WidgetGalleryItem], Never> { get }
    var setting: AnyPublisher<WidgetAppearanceSettings, Never> { get }
    var defaultStyles: AnyPublisher<[String: any WidgetStyleSetting], Never> { get }
}

final class WidgetGalleryViewModelImple: WidgetGalleryViewModel, @unchecked Sendable {

    private let uiSettingUsecase: any UISettingUsecase
    private let widgetStyleUsecase: any WidgetStyleUsecase
    var router: (any WidgetGalleryRouting)?

    init(
        setting: WidgetAppearanceSettings,
        uiSettingUsecase: any UISettingUsecase,
        widgetStyleUsecase: any WidgetStyleUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.widgetStyleUsecase = widgetStyleUsecase
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
            self.widgetStyleUsecase.refreshStyles(TodayStyleSetting.self, of: $0)
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

    var defaultStyles: AnyPublisher<[String: any WidgetStyleSetting], Never> {
        // 꾸미기 가능한 변형이 Today 뿐이라 payload 타입도 하나다.
        let entryStreams = self.customizableVariants.map { variant in
            return self.widgetStyleUsecase.styles(TodayStyleSetting.self, of: variant)
                .compactMap { $0.first }
                .map { [variant.id: $0.setting as any WidgetStyleSetting] }
                .eraseToAnyPublisher()
        }
        return Publishers.MergeMany(entryStreams)
            .scan([String: any WidgetStyleSetting]()) { styles, entry in
                return styles.merging(entry) { _, newStyle in newStyle }
            }
            .eraseToAnyPublisher()
    }
}
