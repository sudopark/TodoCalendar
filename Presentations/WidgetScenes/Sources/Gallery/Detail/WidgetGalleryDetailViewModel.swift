//
//  WidgetGalleryDetailViewModel.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain
import Extensions
import Scenes


protocol WidgetGalleryDetailViewModel: AnyObject, WidgetGalleryDetailSceneInteractor {
    
    func refresh()
    func editStyle(_ variant: WidgetVariant)
    func close()
    
    var itemName: AnyPublisher<String, Never> { get }
    var variants: AnyPublisher<[WidgetVariant], Never> { get }
    var setting: AnyPublisher<WidgetAppearanceSettings, Never> { get }
    var defaultStyles: AnyPublisher<[String: any WidgetStyleSetting], Never> { get }
}

final class WidgetGalleryDetailViewModelImple: WidgetGalleryDetailViewModel, @unchecked Sendable {
    
    private let item: WidgetGalleryItem
    private let currentSetting: WidgetAppearanceSettings
    private let widgetStyleUsecase: any WidgetStyleUsecase
    var router: (any WidgetGalleryDetailRouting)?
    
    init(
        item: WidgetGalleryItem,
        setting: WidgetAppearanceSettings,
        widgetStyleUsecase: any WidgetStyleUsecase
    ) {
        self.item = item
        self.currentSetting = setting
        self.widgetStyleUsecase = widgetStyleUsecase
    }
    
    private let defaultStyleMap = CurrentValueSubject<[String: any WidgetStyleSetting], Never>([:])
}

extension WidgetGalleryDetailViewModelImple {
    
    /// 편집 화면에서 돌아오면 저장된 스타일이 바뀌어 있을 수 있어 미리보기를 다시 읽는다.
    func refresh() {
        let styles = self.item.variants
            .filter { $0.isCustomizable }
            .reduce(into: [String: any WidgetStyleSetting]()) { acc, variant in
                // 꾸미기 가능한 변형이 Today 뿐이라 payload 타입도 하나다.
                acc[variant.id] = self.widgetStyleUsecase
                    .loadStyles(TodayStyleSetting.self, of: variant).first?.setting
            }
        self.defaultStyleMap.send(styles)
    }
    
    func editStyle(_ variant: WidgetVariant) {
        self.router?.routeToStyleEdit(variant, setting: self.currentSetting)
    }
    
    func close() {
        self.router?.closeScene()
    }
}

extension WidgetGalleryDetailViewModelImple {
    
    var itemName: AnyPublisher<String, Never> {
        return Just(self.item.name).eraseToAnyPublisher()
    }
    
    var variants: AnyPublisher<[WidgetVariant], Never> {
        return Just(self.item.variants).eraseToAnyPublisher()
    }
    
    var setting: AnyPublisher<WidgetAppearanceSettings, Never> {
        return Just(self.currentSetting).eraseToAnyPublisher()
    }
    
    var defaultStyles: AnyPublisher<[String: any WidgetStyleSetting], Never> {
        return self.defaultStyleMap.eraseToAnyPublisher()
    }
}
