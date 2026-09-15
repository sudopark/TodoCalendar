//
//  TodayStyleSelectIntentFactory.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/15/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


struct TodayStyleSelectIntentFactory {

    private let base: AppExtensionBase

    init(base: AppExtensionBase) {
        self.base = base
    }
}

extension TodayStyleSelectIntentFactory {

    /// 기본 스타일을 맨 앞에 세우는 규칙이 usecase 에 있어 저장소를 직접 부르지 않는다.
    func makeStyleUsecase() -> any WidgetStyleUsecase {
        return WidgetStyleUsecaseImple(
            styleRepository: WidgetStyleLocalRepositoryImple(
                environmentStorage: self.base.userDefaultEnvironmentStorage
            ),
            sharedDataStore: SharedDataStore()
        )
    }
}
