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
    var previewStyles: AnyPublisher<[String: WidgetPreviewStyleStack], Never> { get }
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
}

extension WidgetGalleryDetailViewModelImple {
    
    func refresh() {
        self.customizableVariants.forEach {
            self.widgetStyleUsecase.refreshStyles(TodayStyleSetting.self, of: $0)
        }
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
    
    private var customizableVariants: [WidgetVariant] {
        return self.item.variants.filter { $0.isCustomizable }
    }
    
    var previewStyles: AnyPublisher<[String: WidgetPreviewStyleStack], Never> {
        // 꾸미기 가능한 변형이 Today 뿐이라 payload 타입도 하나다.
        let entryStreams = self.customizableVariants
            .map { variant in
                return self.widgetStyleUsecase.styles(TodayStyleSetting.self, of: variant)
                    .compactMap { styles in
                        return WidgetPreviewStyleStack(
                            styles: styles.map { $0.setting as any WidgetStyleSetting }
                        )
                    }
                    .map { [variant.id: $0] }
                    .eraseToAnyPublisher()
            }
        guard entryStreams.isEmpty == false else {
            return Just([:]).eraseToAnyPublisher()
        }
        return Publishers.MergeMany(entryStreams)
            .scan([String: WidgetPreviewStyleStack]()) { stacks, entry in
                return stacks.merging(entry) { _, newStack in newStack }
            }
            .eraseToAnyPublisher()
    }
}
