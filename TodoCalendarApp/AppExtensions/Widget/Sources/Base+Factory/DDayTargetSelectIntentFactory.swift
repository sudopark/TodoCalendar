//
//  DDayTargetSelectIntentFactory.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 7/30/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


struct DDayTargetSelectIntentFactory {

    private let base: AppExtensionBase
    private let usecaseFactory: WidgetUsecaseFactory

    init(base: AppExtensionBase) {
        self.base = base
        self.usecaseFactory = .init(base: base)
    }
}

extension DDayTargetSelectIntentFactory {

    func makeEventFetchUsecase() -> any CalendarEventFetchUsecase {
        return self.usecaseFactory.makeEventsFetchUsecase()
    }

    func makeHolidayFetchUsecase() -> any HolidaysFetchUsecase {
        return self.usecaseFactory.makeHolidaysFetchUsecase()
    }

    func loadTimeZone() -> TimeZone {
        let repository = CalendarSettingRepositoryImple(
            environmentStorage: self.base.userDefaultEnvironmentStorage
        )
        return repository.loadUserSelectedTImeZone() ?? .current
    }
}
