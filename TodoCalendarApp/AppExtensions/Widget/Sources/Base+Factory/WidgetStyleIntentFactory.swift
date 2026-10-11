//
//  WidgetStyleIntentFactory.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


struct WidgetStyleIntentFactory {

    private let base: AppExtensionBase

    init(base: AppExtensionBase) {
        self.base = base
    }
}

extension WidgetStyleIntentFactory {

    /// 기본 스타일을 맨 앞에 세우는 규칙이 usecase 에 있어 저장소를 직접 부르지 않는다.
    func makeStyleUsecase() -> any WidgetStyleUsecase {
        return WidgetStyleUsecaseImple(
            styleRepository: WidgetStyleLocalRepositoryImple(
                environmentStorage: self.base.userDefaultEnvironmentStorage,
                photoDirectory: AppEnvironment.widgetPhotoDirectory
            ),
            sharedDataStore: SharedDataStore()
        )
    }

    /// 후보에만 쓴다 — 복원까지 거르면 걸린 커스텀이 기본 스타일로 바뀐다
    func loadSelectableStyles(of variant: WidgetVariant) -> [WidgetStyle] {
        let gate = WidgetUsecaseFactory(base: self.base).makeWidgetStylePaidFeatureGateUsecase()
        return self.makeStyleUsecase().loadStyles(of: variant)
            .selectable(by: gate, at: Date())
    }
}


// MARK: - 후보 거르기

extension Array where Element == WidgetStyle {

    func selectable(
        by gate: any WidgetStylePaidFeatureGateUsecase, at now: Date
    ) -> [WidgetStyle] {
        guard gate.canCreateCustomWidgetStyleWithoutAd(at: now) == false
        else { return self }
        return self.filter { $0.id.style == .default }
    }
}
