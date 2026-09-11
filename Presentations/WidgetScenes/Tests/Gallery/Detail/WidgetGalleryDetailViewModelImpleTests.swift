//
//  WidgetGalleryDetailViewModelImpleTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Domain
import Extensions
import TestDoubles

@testable import WidgetScenes


final class SpyWidgetGalleryDetailRouter: BaseSpyRouter, WidgetGalleryDetailRouting, @unchecked Sendable { }


struct WidgetGalleryDetailViewModelImpleTests {

    private let cancellables = CancelBag()

    private func makeViewModel(
        _ item: WidgetGalleryItem,
        router: SpyWidgetGalleryDetailRouter,
        setting: WidgetAppearanceSettings = .init()
    ) -> WidgetGalleryDetailViewModelImple {
        let viewModel = WidgetGalleryDetailViewModelImple(item: item, setting: setting)
        viewModel.router = router
        return viewModel
    }

    private var ddayItem: WidgetGalleryItem { return .dday }

    @Test
    func viewModel_emitsVariantsOfGivenItem() {
        // given
        let item = self.ddayItem
        let viewModel = self.makeViewModel(item, router: .init())
        var emitted: [WidgetVariant]?

        // when
        viewModel.variants
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // then
        #expect(emitted?.map { $0.id } == item.variants.map { $0.id })
        #expect(emitted?.map { $0.canvas.isLockScreen } == [false, false, true, true, true])
    }

    @Test
    func viewModel_emitsItemName() {
        // given
        let item = self.ddayItem
        let viewModel = self.makeViewModel(item, router: .init())
        var emitted: String?

        // when
        viewModel.itemName
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)

        // then
        #expect(emitted == item.name)
    }

    @Test
    func viewModel_emitsGivenSetting() {
        // given
        let setting = WidgetAppearanceSettings() |> \.background .~ .custom(hex: "#123456")
        let viewModel = self.makeViewModel(self.ddayItem, router: .init(), setting: setting)
        var emitted: WidgetAppearanceSettings?
        
        // when
        viewModel.setting
            .sink(receiveValue: { emitted = $0 })
            .store(in: self.cancellables)
        
        // then
        #expect(emitted?.background == .custom(hex: "#123456"))
    }
    
    @Test
    func viewModel_whenClose_routesToCloseScene() {
        // given
        let router = SpyWidgetGalleryDetailRouter()
        let viewModel = self.makeViewModel(self.ddayItem, router: router)

        // when
        viewModel.close()

        // then
        #expect(router.didClosed == true)
    }
}
