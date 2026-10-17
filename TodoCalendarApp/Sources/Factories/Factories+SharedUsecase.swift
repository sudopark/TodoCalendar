//
//  Factories+SharedUsecase.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 9/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import SpeechService
import PlaceService
import Repository


// MARK: - CalendarFactory

struct CalendarFactory {

    let applicationBase: ApplicationBase

    func makeCalendarSettingUsecase() -> any CalendarSettingUsecase {
        let settingRepository = CalendarSettingRepositoryImple(
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        return CalendarSettingUsecaseImple(
            settingRepository: settingRepository,
            shareDataStore: applicationBase.sharedDataStore
        )
    }

    func makeHolidayUsecase() -> any HolidayUsecase {
        let holidayRepository = HolidayRepositoryImple(
            localEnvironmentStorage: applicationBase.userDefaultEnvironmentStorage,
            sqliteService: applicationBase.commonSqliteService,
            remoteAPI: applicationBase.remoteAPI
        )
        return HolidayUsecaseImple(
            holidayRepository: holidayRepository,
            dataStore: applicationBase.sharedDataStore,
            localeProvider: Locale.current
        )
    }

    func makeCalendarUsecase() -> any CalendarUsecase {
        return CalendarUsecaseImple(
            calendarSettingUsecase: self.makeCalendarSettingUsecase(),
            holidayUsecase: self.makeHolidayUsecase()
        )
    }
}



// MARK: - CommonFactory

struct CommonFactory {

    let applicationBase: ApplicationBase

    func makeLinkPreviewFetchUsecase() -> any LinkPreviewFetchUsecase {
        return LinkPreviewFetchUsecaseImple(
            previewEngine: applicationBase.linkPreviewFetchEngine
        )
    }

    func makePlaceSuggestUsecase() -> any PlaceSuggestUsecase {
        return PlaceSuggestUsecaseImple(
            suggestEngine: MapKitBasePlaceSuggestEngineImple()
        )
    }

    func deviceInfoFetchService() -> any DeviceInfoFetchService {
        return DeviceInfoFetchServiceImple()
    }
}



// MARK: - SupportFactory

struct SupportFactory {

    let applicationBase: ApplicationBase
    let accountUsecase: any AccountUsecase

    func makeFeedbackUsecase() -> any FeedbackUsecase {
        let feedbackRepository = FeedbackRepositoryImple(remote: self.applicationBase.remoteAPI)
        return FeedbackUsecaseImple(
            accountUsecase: self.accountUsecase,
            feedbackRepository: feedbackRepository,
            deviceInfoFetchService: DeviceInfoFetchServiceImple()
        )
    }

    func makeGuideTodoUsecase() -> any GuideTodoUsecase {
        return GuideTodoUsecaseImple(
            repository: GuideTodoLocalRepositoryImple(
                environmentStorage: self.applicationBase.userDefaultEnvironmentStorage
            ),
            sharedDataStore: self.applicationBase.sharedDataStore
        )
    }

    func makeLegalNoticeUsecase() -> any LegalNoticeUsecase {
        return LegalNoticeUsecaseImple(
            legalNoticeRepository: LegalNoticeRepositoryImple(
                remoteAPI: self.applicationBase.remoteAPI,
                environmentStorage: self.applicationBase.userDefaultEnvironmentStorage
            )
        )
    }
}



// MARK: - SpeechFactory

struct SpeechFactory {

    func makeSpeechRecognizeUsecase() -> any SpeechRecognizeUsecase {
        return SpeechRecognizeUsecaseImple(
            service: SpeechRecognizeServiceImple(),
            permissionChecker: SpeechRecognizePermissionCheckerImple()
        )
    }
}
