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

    func selectItem(_ itemId: String)
    func selectSystemTheme()
    func selectCustomBackground(hex: String)
    func close()

    var items: AnyPublisher<[WidgetGalleryItem], Never> { get }
    var setting: AnyPublisher<WidgetAppearanceSettings, Never> { get }
}

final class WidgetGalleryViewModelImple: WidgetGalleryViewModel, @unchecked Sendable {

    private let uiSettingUsecase: any UISettingUsecase
    var router: (any WidgetGalleryRouting)?

    init(
        setting: WidgetAppearanceSettings,
        uiSettingUsecase: any UISettingUsecase
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.subject.setting.send(setting)
    }

    private struct Subject {
        let setting = CurrentValueSubject<WidgetAppearanceSettings?, Never>(nil)
    }
    private let subject = Subject()
}


// MARK: - handle events

extension WidgetGalleryViewModelImple {

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

    var items: AnyPublisher<[WidgetGalleryItem], Never> {
        return Just(self.availableItems).eraseToAnyPublisher()
    }

    var setting: AnyPublisher<WidgetAppearanceSettings, Never> {
        return self.subject.setting
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
