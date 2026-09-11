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
    
    func close()
    
    var itemName: AnyPublisher<String, Never> { get }
    var variants: AnyPublisher<[WidgetVariant], Never> { get }
    var setting: AnyPublisher<WidgetAppearanceSettings, Never> { get }
}

final class WidgetGalleryDetailViewModelImple: WidgetGalleryDetailViewModel, @unchecked Sendable {
    
    private let item: WidgetGalleryItem
    private let currentSetting: WidgetAppearanceSettings
    var router: (any WidgetGalleryDetailRouting)?
    
    init(item: WidgetGalleryItem, setting: WidgetAppearanceSettings) {
        self.item = item
        self.currentSetting = setting
    }
}

extension WidgetGalleryDetailViewModelImple {
    
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
}
