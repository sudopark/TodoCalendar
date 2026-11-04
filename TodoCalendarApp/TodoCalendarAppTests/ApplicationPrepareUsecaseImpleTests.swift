//
//  ApplicationPrepareUsecaseImpleTests.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 10/14/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Testing
import Combine
import GoogleMobileAds
import SQLiteService
import Domain
import Repository
import AdService
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import TodoCalendarApp


final class ApplicationPrepareUsecaseImpleTests {

    private let appSettingRepository = StubAppSettingRepository()
    private let sharedDataStore = SharedDataStore()
    private let databaseDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ApplicationPrepareUsecaseImpleTests-\(UUID().uuidString)")

    deinit {
        try? FileManager.default.removeItem(at: self.databaseDirectory)
    }

    private func makeUsecase(savedColorSetKey: ColorSetKeys) -> ApplicationPrepareUsecaseImple {
        self.appSettingRepository.stubAppearanceSetting = .init(
            calendar: .init(colorSetKey: savedColorSetKey, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "holiday", default: "default")
        )
        try? FileManager.default.createDirectory(at: self.databaseDirectory, withIntermediateDirectories: true)
        let environmentStorage = UserDefaultEnvironmentStorageImple(suiteName: UUID().uuidString)
        let database = SQLiteService()
        return ApplicationPrepareUsecaseImple(
            accountUsecase: StubAccountUsecase(),
            supportExternalServices: [],
            externalCalenarIntegrationUsecase: StubExternalCalendarIntegrationUsecase([]),
            latestAppSettingRepository: self.appSettingRepository,
            sharedDataStore: self.sharedDataStore,
            environmentStorage: environmentStorage,
            coldLaunchHistoryRepository: StubColdLaunchHistoryRepository(),
            customColorThemeRepository: StubCustomColorThemeRepository(),
            mobileAdService: DummyMobileAdService(),
            appPolicyRepository: StubAppPolicyRepository(),
            database: database,
            appDataMigration: AppDataMigrationImple(
                mainDB: database,
                googleCalendarDBPool: NoConnectionPool(),
                migrationFlagStorage: environmentStorage,
                dbVersion: AppEnvironment.dbVersion
            ),
            databasePathFinding: { [databaseDirectory] in
                databaseDirectory.appendingPathComponent("models_\($0 ?? "none").db").path
            }
        )
    }

    private func prepareAccountChanged(_ usecase: ApplicationPrepareUsecaseImple, isSignIn: Bool) async {
        if isSignIn {
            await usecase.prepareSignedIn(.init(uid: "uid", accessToken: "token"))
        } else {
            await usecase.prepareSignedOut()
        }
    }

    private var sharedColorSetKey: ColorSetKeys? {
        return self.sharedDataStore
            .value(CalendarAppearanceSettings.self, key: ShareDataKeys.calendarAppearance.rawValue)?
            .colorSetKey
    }
}


// MARK: - 계정 전환 때 컬러 테마 선택

extension ApplicationPrepareUsecaseImpleTests {

    @Test("로그인·로그아웃 때 커스텀 테마 선택은 시스템 테마로 되돌린다", arguments: [true, false])
    func usecase_whenAccountChanged_resetsCustomColorThemeSelection(_ isSignIn: Bool) async {
        // given
        let usecase = self.makeUsecase(savedColorSetKey: .custom("c1"))

        // when
        await self.prepareAccountChanged(usecase, isSignIn: isSignIn)

        // then
        #expect(self.appSettingRepository.loadSavedViewAppearance().calendar.colorSetKey == .systemTheme)
        #expect(self.sharedColorSetKey == .systemTheme)
    }

    @Test("로그인·로그아웃 때 커스텀이 아닌 테마 선택은 그대로 둔다", arguments: [true, false])
    func usecase_whenAccountChanged_keepsNonCustomColorThemeSelection(_ isSignIn: Bool) async {
        // given
        let usecase = self.makeUsecase(savedColorSetKey: .appTheme(.tomato))

        // when
        await self.prepareAccountChanged(usecase, isSignIn: isSignIn)

        // then
        #expect(self.appSettingRepository.loadSavedViewAppearance().calendar.colorSetKey == .appTheme(.tomato))
        #expect(self.sharedColorSetKey == .appTheme(.tomato))
        #expect(self.appSettingRepository.didChangeCalendarAppearanceSettingParams == nil)
    }
}


private final class StubColdLaunchHistoryRepository: AppColdLaunchHistoryRepository, @unchecked Sendable {

    func loadColdLaunchHistory() -> AppColdLaunchHistory { .init() }
    func updateColdLaunchHistory(_ history: AppColdLaunchHistory) { }
}

private final class StubCustomColorThemeRepository: CustomColorThemeRepository, @unchecked Sendable {

    func loadThemes() async throws -> [CustomColorTheme] { [] }
    func fetchTheme(_ uuid: String) async throws -> CustomColorTheme? { nil }
    func saveTheme(_ theme: CustomColorTheme) async throws { }
    func removeTheme(_ uuid: String) async throws { }
}

private final class StubAppPolicyRepository: AppPolicyRepository, @unchecked Sendable {

    func loadPolicy() -> AppPolicy? { nil }
    func refreshPolicy() async throws { }
}

private final class NoConnectionPool: ExternalCalendarDBConnectionPool, @unchecked Sendable {

    func hasConnection(serviceId: String) async -> Bool { false }
    func connection(serviceId: String) async throws -> SQLiteService {
        throw RuntimeError("no connection")
    }
}

private final class DummyMobileAdService: MobileAdService, @unchecked Sendable {

    var isStarted: AnyPublisher<Bool, Never> { Just(true).eraseToAnyPublisher() }
    var isStartedNow: Bool { true }

    func start() { }

    @MainActor
    var isTrackingAuthorizationDetermined: Bool { false }

    func presentConsentFormIfNeeded(from viewController: UIViewController) async { }

    @MainActor
    func requestTrackingAuthorization() async { }

    func preloadFullScreenAd() async { }
    func takePreloadedFullScreenAd() -> InterstitialAd? { nil }
    func preloadRewardedAd() async { }
    func takeRewardedAd(waitingUpTo timeout: TimeInterval) async -> RewardedAd? { nil }

    @MainActor
    func isPrivacyOptionsRequired() -> Bool { false }

    @MainActor
    func showPrivacyOptionsForm(from viewController: UIViewController) async throws { }
}
