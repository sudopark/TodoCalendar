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
            self.widgetStyleUsecase.refreshStyles(of: $0)
        }
    }
    
    /// 저장 후 리로드가 받은 변형들의 kind 를 훑으므로, 좌표를 공유하는 변형을 다 넘겨야 전부 갱신된다.
    func editStyle(_ variant: WidgetVariant) {
        self.router?.routeToStyleEdit(
            variant.styleSharingVariants, setting: self.currentSetting
        )
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
        let entryStreams = self.customizableVariants
            .map { variant in
                return self.widgetStyleUsecase.styles(of: variant)
                    .compactMap { styles in
                        return WidgetPreviewStyleStack(styles: styles)
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
