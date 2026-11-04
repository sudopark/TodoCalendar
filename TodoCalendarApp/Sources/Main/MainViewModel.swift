//
//  
//  MainViewModel.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/26.
//
//

import Foundation
import UIKit
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes
import AdService


// MARK: - MainViewModel

enum TemporaryUserDataMigrationStatus: Equatable {
    case need(_ count: Int)
    case migrating
}

public struct CurrentMonth: Equatable {
    let monthText: String
    var yearText: String?
}

struct LegalNoticeBannerModel: Equatable {
    let documentType: LegalDocumentType
    let message: String
    let effectiveDateText: String
}

protocol MainViewModel: AnyObject, Sendable, MainSceneInteractor {

    // interactor
    func prepare()
    func moveToPreviousMonth()
    func moveToNextMonth()
    func handleMigration()
    func moveToEventTypeFilterSetting()
    func moveToSetting()
    func jumpDate()
    func openLegalNoticeDocument(_ documentType: LegalDocumentType)
    func closeLegalNoticeBanner(_ documentType: LegalDocumentType)
    func requestTrackingThenShowLaunchAd(canShowLaunchAd: Bool)

    // presenter
    var currentMonth: AnyPublisher<CurrentMonth, Never> { get }
    var isMonthNavigationHidden: AnyPublisher<Bool, Never> { get }
    var temporaryUserDataMigrationStatus: AnyPublisher<TemporaryUserDataMigrationStatus?, Never> { get }
    var isLoadingCalendarEvents: AnyPublisher<Bool, Never> { get }
    var isLoadingAllEvents: AnyPublisher<Bool, Never> { get }
    var legalNoticeBanners: AnyPublisher<[LegalNoticeBannerModel], Never> { get }
    var hasNewFeatureBadge: AnyPublisher<Bool, Never> { get }
}


// MARK: - MainViewModelImple

final class MainViewModelImple: MainViewModel, @unchecked Sendable {
    
    private let uiSettingUsecase: any UISettingUsecase
    private let temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase
    private let eventNotificationUsecase: any EventNotificationUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventNotifyService: SharedEventNotifyService
    private let googleCalendarUsecase: any GoogleCalendarUsecase
    private let appleCalendarUsecase: any AppleCalendarUsecase
    private let eventSyncUsecase: any EventSyncUsecase
    private let billingUsecase: any BillingUsecase
    private let aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase
    private let eventLiveActivityUsecase: any EventLiveActivityUsecase
    private let guideTodoUsecase: any GuideTodoUsecase
    private let newFeatureBadgeUsecase: any NewFeatureBadgeUsecase
    private let legalNoticeUsecase: any LegalNoticeUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let paidFeatureGateUsecase: any PaidFeatureGateUsecase
    private let adExposureUsecase: any AdExposureUsecase
    private let mobileAdService: any MobileAdService
    var router: (any MainRouting)?

    init(
        uiSettingUsecase: any UISettingUsecase,
        temporaryUserDataMigrationUsecase: any TemporaryUserDataMigrationUescase,
        eventNotificationUsecase: any EventNotificationUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventNotifyService: SharedEventNotifyService,
        googleCalendarUsecase: any GoogleCalendarUsecase,
        appleCalendarUsecase: any AppleCalendarUsecase,
        eventSyncUsecase: any EventSyncUsecase,
        billingUsecase: any BillingUsecase,
        aiAgentOrchestrationUsecase: any AIAgentOrchestrationUsecase,
        eventLiveActivityUsecase: any EventLiveActivityUsecase,
        guideTodoUsecase: any GuideTodoUsecase,
        newFeatureBadgeUsecase: any NewFeatureBadgeUsecase,
        legalNoticeUsecase: any LegalNoticeUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        paidFeatureGateUsecase: any PaidFeatureGateUsecase,
        adExposureUsecase: any AdExposureUsecase,
        mobileAdService: any MobileAdService
    ) {
        self.uiSettingUsecase = uiSettingUsecase
        self.temporaryUserDataMigrationUsecase = temporaryUserDataMigrationUsecase
        self.eventNotificationUsecase = eventNotificationUsecase
        self.eventTagUsecase = eventTagUsecase
        self.eventNotifyService = eventNotifyService
        self.googleCalendarUsecase = googleCalendarUsecase
        self.appleCalendarUsecase = appleCalendarUsecase
        self.eventSyncUsecase = eventSyncUsecase
        self.billingUsecase = billingUsecase
        self.aiAgentOrchestrationUsecase = aiAgentOrchestrationUsecase
        self.eventLiveActivityUsecase = eventLiveActivityUsecase
        self.guideTodoUsecase = guideTodoUsecase
        self.newFeatureBadgeUsecase = newFeatureBadgeUsecase
        self.legalNoticeUsecase = legalNoticeUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.paidFeatureGateUsecase = paidFeatureGateUsecase
        self.adExposureUsecase = adExposureUsecase
        self.mobileAdService = mobileAdService

        self.internalBinding()
    }

    private struct Subject {
        let focusedDayInfo = CurrentValueSubject<SelectDayInfo?, Never>(nil)
        let calendarColumnLayout = CurrentValueSubject<CalendarColumnLayout?, Never>(nil)
        let temporaryUserDataMigrationStatus = CurrentValueSubject<TemporaryUserDataMigrationStatus?, Never>(nil)
    }
    
    private let cancellables = CancelBag()
    private let subject = Subject()
    private var calendarSceneInteractor: (any CalendarSceneInteractor)?
    private var isLicenseGateInProgress: Bool = false
    
    private func internalBinding() {
        
        self.temporaryUserDataMigrationUsecase.isMigrating
            .filter { $0 }
            .sink(receiveValue: { [weak self] _ in
                self?.subject.temporaryUserDataMigrationStatus.send(.migrating)
            })
            .store(in: self.cancellables)
        
        self.temporaryUserDataMigrationUsecase.migrationNeedEventCount
            .filter { $0 > 0 }
            .sink(receiveValue: { [weak self] count in
                self?.subject.temporaryUserDataMigrationStatus.send(.need(count))
            })
            .store(in: self.cancellables)
        
        self.temporaryUserDataMigrationUsecase.migrationResult
            .sink(receiveValue: { [weak self] result in
                self?.subject.temporaryUserDataMigrationStatus.send(nil)
                switch result {
                case .success:
                    self?.router?.showToast("manage_account::migration_finished::message".localized())
                case .failure(let error):
                    self?.router?.showError(error)
                }
            })
            .store(in: self.cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink(receiveValue: { [weak self] _ in
                self?.billingUsecase.recoverUnfinishedTransactions()
                self?.aiAgentOrchestrationUsecase.refreshProcessingJobIfNeeded()
                self?.aiAgentOrchestrationUsecase.loadUsage()
                self?.aiAgentOrchestrationUsecase.refreshNotificationPermissionStatus()
                self?.handleWillEnterForeground()
                self?.legalNoticeUsecase.checkNoticeIsNeed()
                self?.foremostEventUsecase.refresh()
            })
            .store(in: self.cancellables)
    }

}


// MARK: - MainViewModelImple Interactor

extension MainViewModelImple {
    
    func prepare() {
        Task { @MainActor in
            self.calendarSceneInteractor = self.router?.attachCalendar()
        }
        self.refreshViewAppearanceSettings()
        self.temporaryUserDataMigrationUsecase.checkIsNeedMigration()
        
        self.eventNotificationUsecase.runSyncEventNotification()
        self.bindEventTagColorMap()
        self.googleCalendarUsecase.prepare()
        self.appleCalendarUsecase.prepare()
        self.billingUsecase.startObservingTransactions()
        self.billingUsecase.recoverUnfinishedTransactions()
        self.guideTodoUsecase.prepare()
        self.newFeatureBadgeUsecase.prepare()
        self.legalNoticeUsecase.checkNoticeIsNeed()
        Task { [weak self] in
            await self?.eventLiveActivityUsecase.prepare()
        }
        self.bindColorThemeLicenseGate()
    }

    private func handleWillEnterForeground() {
        Task { [weak self] in
            await self?.eventLiveActivityUsecase.handleWillEnterForeground()
        }
    }
    
    private func refreshViewAppearanceSettings() {
        Task { [weak self] in
            _ = try await self?.uiSettingUsecase.refreshAppearanceSetting()
        }
        .store(in: self.cancellables)
    }
    
    private func bindEventTagColorMap() {
        
        self.eventTagUsecase.sharedEventTags
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tags in
                self?.uiSettingUsecase.applyEventTagColors(Array(tags.values))
            })
            .store(in: self.cancellables)
    }
    
    func moveToPreviousMonth() {
        self.calendarSceneInteractor?.moveToPreviousMonth()
    }

    func moveToNextMonth() {
        self.calendarSceneInteractor?.moveToNextMonth()
    }

    func handleMigration() {
        guard let status = self.subject.temporaryUserDataMigrationStatus.value,
              case .need(let count) = status
        else { return }
        
        let runMigration: () -> Void = { [weak self] in
            self?.temporaryUserDataMigrationUsecase.startMigration()
        }
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("manage_account::migration::title".localized())
            |> \.message .~ pure("manage_account::migration::description".localized(with: count))
            |> \.withCancel .~ true
            |> \.confirmed .~ pure(runMigration)
        self.router?.showConfirm(dialog: info)
    }
    
    func moveToEventTypeFilterSetting() {
        self.router?.routeToEventTypeFilterSetting()
    }
    
    func moveToSetting() {
        self.router?.routeToSettingScene()
    }
    
    func calendarScene(focusChangedTo selected: SelectDayInfo) {
        self.subject.focusedDayInfo.send(selected)
    }

    func calendarScene(didChangeColumnLayout layout: CalendarColumnLayout) {
        self.subject.calendarColumnLayout.send(layout)
    }

    
    func jumpDate() {
        guard let current = self.subject.focusedDayInfo.value else { return }
        self.router?.showJumpDaySelectDialog(current: current.dayInfo)
    }
    
    func handleAIJobStatusChanged(_ jobId: String) {
        self.aiAgentOrchestrationUsecase.handleJobStatusChanged(jobId)
    }

    func daySelectDialog(didSelect day: SelectDayInfo) {
        guard let current = self.subject.focusedDayInfo.value,
              current.dayInfo != day.dayInfo
        else { return }
        self.calendarSceneInteractor?.moveDay(day.dayInfo)
    }

    func openLegalNoticeDocument(_ documentType: LegalDocumentType) {
        self.router?.showWebView(documentType.linkPath)
    }

    func closeLegalNoticeBanner(_ documentType: LegalDocumentType) {
        self.legalNoticeUsecase.confirmNotice(documentType)
    }
}


// MARK: - 컬러 테마 사용권 만료 게이트

extension MainViewModelImple {

    private func bindColorThemeLicenseGate() {
        let colorThemeKey = self.uiSettingUsecase.currentCalendarUISeting
            .map { $0.colorSetKey }
            .removeDuplicates()
        let enterForeground = NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .map { _ in () }
        let userPlanChanged = self.billingUsecase.currentUserPlan
            .map { $0.isPaid }
            .removeDuplicates()
            .map { _ in () }
        let checkTriggers = Publishers.Merge3(Just(()), enterForeground, userPlanChanged)

        Publishers.CombineLatest(colorThemeKey, checkTriggers)
            .map { key, _ in key }
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] key in
                self?.showColorThemeLicenseExpiredGuideIfNeeded(key)
            })
            .store(in: self.cancellables)
    }

    private func colorThemeLicenseExpiredReason(_ key: ColorSetKeys) -> PaidFeatureGateFailReason? {
        do {
            try self.paidFeatureGateUsecase.check(.colorTheme(key), at: Date())
            return nil
        } catch {
            return error as? PaidFeatureGateFailReason
        }
    }

    private func showColorThemeLicenseExpiredGuideIfNeeded(_ key: ColorSetKeys) {
        let reason = self.colorThemeLicenseExpiredReason(key)
        guard let reason, self.isLicenseGateInProgress == false else { return }

        self.isLicenseGateInProgress = true
        // 메인이 띄운 화면이 남아 있으면 UIKit 이 present 를 거부해 onFinished 가 오지 않는다
        self.router?.dismissPresented(animated: true) { [weak self] in
            self?.showColorThemeLicenseExpiredGuide(reason)
        }
    }

    private func showColorThemeLicenseExpiredGuide(_ reason: PaidFeatureGateFailReason) {
        self.router?.showColorThemeLicenseExpiredGuide(
            reason,
            onFinished: { [weak self] _ in
                self?.isLicenseGateInProgress = false
            },
            onUseDefault: { [weak self] in
                self?.changeColorThemeToSystemTheme()
            }
        )
    }

    private func changeColorThemeToSystemTheme() {
        let params = EditCalendarAppearanceSettingParams()
            |> \.newColorSetKey .~ .systemTheme
        do {
            _ = try self.uiSettingUsecase.changeCalendarAppearanceSetting(params)
        } catch {
            self.router?.showError(error)
        }
    }
}


// MARK: - MainViewModelImple Presenter

extension MainViewModelImple {

    var isMonthNavigationHidden: AnyPublisher<Bool, Never> {
        return self.subject.calendarColumnLayout
            .compactMap { $0 }
            .map { $0 == .twoColumns }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var currentMonth: AnyPublisher<CurrentMonth, Never> {
        
        let formatter = DateFormatter() |> \.dateFormat .~ "date_form.MMM".localized()
        let calednar = Calendar(identifier: .gregorian)
        let transform: (SelectDayInfo?) -> CurrentMonth? = { info in
            guard let info else { return nil }
            guard let date = calednar.date(bySetting: .month, value: info.month, of: Date())
            else {
                return .init(monthText: "\(info.month)")
            }
            return .init(
                monthText: formatter.string(from: date).uppercased(),
                yearText: info.isCurrentYear ? nil : "\(info.year)"
            )
        }
        
        return self.subject.focusedDayInfo
            .compactMap(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var temporaryUserDataMigrationStatus: AnyPublisher<TemporaryUserDataMigrationStatus?, Never> {
        return self.subject.temporaryUserDataMigrationStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var hasNewFeatureBadge: AnyPublisher<Bool, Never> {
        return self.newFeatureBadgeUsecase.uncheckedBadges
            .map { !$0.isEmpty }
            .eraseToAnyPublisher()
    }
    
    var isLoadingCalendarEvents: AnyPublisher<Bool, Never> {
        return self.eventSyncUsecase.isSyncInProgress
            .eraseToAnyPublisher()
    }

    var isLoadingAllEvents: AnyPublisher<Bool, Never> {
        return self.eventSyncUsecase.syncStatus
            .map { $0 == .fullSyncing }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var legalNoticeBanners: AnyPublisher<[LegalNoticeBannerModel], Never> {

        let message: (LegalDocumentType) -> String = { documentType in
            switch documentType {
            case .terms: return "legal_notice.message::terms".localized()
            case .privacy: return "legal_notice.message::privacy".localized()
            }
        }
        let dateFormatter = DateFormatter()
            |> \.dateFormat .~ "date_form.yyyy_MM_dd".localized()
            |> \.timeZone .~ TimeZone(secondsFromGMT: 0)

        return self.legalNoticeUsecase.pendingNoticeUpdates
            .map { updates -> [LegalNoticeBannerModel] in
                return updates.map { info in
                    let effectiveDateText = "legal_notice.effectiveDate".localized(
                        with: dateFormatter.string(from: info.effectiveDate)
                    )
                    return LegalNoticeBannerModel(
                        documentType: info.documentType,
                        message: message(info.documentType),
                        effectiveDateText: effectiveDateText
                    )
                }
            }
            .eraseToAnyPublisher()
    }
}


// MARK: - 추적 권한 요청

extension MainViewModelImple {

    func requestTrackingThenShowLaunchAd(canShowLaunchAd: Bool) {
        Task { [weak self] in
            guard let self else { return }
            guard await self.adExposureUsecase.canRequestTrackingAuthorization() else {
                self.showLaunchAdIfCan(canShowLaunchAd)
                return
            }

            self.adExposureUsecase.recordTrackingGuideShown()
            self.router?.showTrackingGuide(
                onContinue: { [weak self] in
                    self?.requestSystemTrackingThenShowLaunchAd(canShowLaunchAd)
                },
                onDecline: { [weak self] in
                    self?.showLaunchAdIfCan(canShowLaunchAd)
                }
            )
        }
    }

    private func requestSystemTrackingThenShowLaunchAd(_ canShowLaunchAd: Bool) {
        Task { @MainActor [weak self] in
            await self?.mobileAdService.requestTrackingAuthorization()
            self?.showLaunchAdIfCan(canShowLaunchAd)
        }
    }

    private func showLaunchAdIfCan(_ canShowLaunchAd: Bool) {
        guard canShowLaunchAd else { return }
        self.router?.showLaunchFullScreenAd()
    }
}
