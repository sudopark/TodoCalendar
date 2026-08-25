//
//  MainViewModelImpleTests.swift
//  TodoCalendarAppTests
//
//  Created by sudo.park on 2023/08/27.
//

import XCTest
import UIKit
import Combine
import Domain
import Scenes
import UnitTestHelpKit
import TestDoubles

@testable import TodoCalendarApp


class MainViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    private var spyRouter: SpyRouter!
    private var spyUISettingUsecase: StubUISettingUsecase!
    private var stubMigrationUsecase: StubTemporaryUserDataMigrationUescase!
    private var spyEventNotificationUsecase: SpyEventNotificationUsecase!
    private var stubEventTagUsecase: StubEventTagUsecase!
    private var stubEventNotifyService: SharedEventNotifyService!
    private var spyGoogleCalendarUsecase: StubGoogleCalendarUsecase!
    private var spyAppleCalendarUsecase: StubAppleCalendarUsecase!
    private var stubSyncUsecase: StubEventSyncUsecase!
    private var spyBillingUsecase: SpyBillingUsecase!
    private var stubAIOrchestrationUsecase: StubAIAgentOrchestrationUsecase!
    private var spyEventLiveActivityUsecase: SpyEventLiveActivityUsecase!
    private var stubGuideTodoUsecase: StubGuideTodoUsecase!
    private var stubLegalNoticeUsecase: StubLegalNoticeUsecase!
    var cancelBag: Set<AnyCancellable>!

    override func setUpWithError() throws {
        self.spyRouter = .init()
        self.spyUISettingUsecase = .init()
        self.stubMigrationUsecase = .init()
        self.spyEventNotificationUsecase = .init()
        self.stubEventTagUsecase = .init()
        self.stubEventNotifyService = .init(notifyQueue: nil)
        self.spyGoogleCalendarUsecase = .init()
        self.spyAppleCalendarUsecase = .init()
        self.stubSyncUsecase = .init()
        self.spyBillingUsecase = .init()
        self.stubAIOrchestrationUsecase = .init()
        self.spyEventLiveActivityUsecase = .init()
        self.stubGuideTodoUsecase = .init()
        self.stubLegalNoticeUsecase = .init()
        self.cancelBag = .init()
        self.timeout = 0.01
    }

    override func tearDownWithError() throws {
        self.spyRouter = nil
        self.spyUISettingUsecase = nil
        self.stubMigrationUsecase = nil
        self.spyEventNotificationUsecase = nil
        self.stubEventTagUsecase = nil
        self.stubEventNotifyService = nil
        self.spyGoogleCalendarUsecase = nil
        self.spyAppleCalendarUsecase = nil
        self.stubSyncUsecase = nil
        self.spyBillingUsecase = nil
        self.stubAIOrchestrationUsecase = nil
        self.spyEventLiveActivityUsecase = nil
        self.stubGuideTodoUsecase = nil
        self.stubLegalNoticeUsecase = nil
        self.cancelBag = nil
    }

    private func makeViewModel(
        shouldFailMigration: Bool = false,
        fullSyncing: Bool = false
    ) -> MainViewModelImple {
        self.stubMigrationUsecase.shouldFail = shouldFailMigration
        self.stubSyncUsecase.stubStatusWhileSyncing = fullSyncing ? .fullSyncing : .incrementalSyncing
        let expect = expectation(description: "wait until attached")
        let viewModel = MainViewModelImple(
            uiSettingUsecase: self.spyUISettingUsecase,
            temporaryUserDataMigrationUsecase: self.stubMigrationUsecase,
            eventNotificationUsecase: self.spyEventNotificationUsecase,
            eventTagUsecase: self.stubEventTagUsecase,
            eventNotifyService: self.stubEventNotifyService,
            googleCalendarUsecase: self.spyGoogleCalendarUsecase,
            appleCalendarUsecase: self.spyAppleCalendarUsecase,
            eventSyncUsecase: self.stubSyncUsecase,
            billingUsecase: self.spyBillingUsecase,
            aiAgentOrchestrationUsecase: self.stubAIOrchestrationUsecase,
            eventLiveActivityUsecase: self.spyEventLiveActivityUsecase,
            guideTodoUsecase: self.stubGuideTodoUsecase,
            legalNoticeUsecase: self.stubLegalNoticeUsecase
        )
        viewModel.router = self.spyRouter
        self.spyRouter.didCalendarAttached = {
            expect.fulfill()
        }
        viewModel.prepare()
        self.wait(for: [expect], timeout: self.timeout)
        // 앞 테스트의 VM 이 아직 살아 있으면 전역 NotificationCenter 방출에 반응해 이미 채워진
        // expectation 을 다시 때린다. XCTest 는 그걸 API violation 어서션으로 처리해 프로세스를 죽인다
        self.spyRouter.didCalendarAttached = nil
        return viewModel
    }
}

extension MainViewModelImpleTests {
    
    private func makeViewModelWithoutPrepare() -> MainViewModelImple {
        let viewModel = MainViewModelImple(
            uiSettingUsecase: self.spyUISettingUsecase,
            temporaryUserDataMigrationUsecase: self.stubMigrationUsecase,
            eventNotificationUsecase: self.spyEventNotificationUsecase,
            eventTagUsecase: self.stubEventTagUsecase,
            eventNotifyService: self.stubEventNotifyService,
            googleCalendarUsecase: self.spyGoogleCalendarUsecase,
            appleCalendarUsecase: self.spyAppleCalendarUsecase,
            eventSyncUsecase: self.stubSyncUsecase,
            billingUsecase: self.spyBillingUsecase,
            aiAgentOrchestrationUsecase: self.stubAIOrchestrationUsecase,
            eventLiveActivityUsecase: self.spyEventLiveActivityUsecase,
            guideTodoUsecase: self.stubGuideTodoUsecase,
            legalNoticeUsecase: self.stubLegalNoticeUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }

    private func makeUpdateInfo(
        id: String = "notice_1",
        documentType: LegalDocumentType,
        effectiveDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> LegalNoticeUpdateInfo {
        return LegalNoticeUpdateInfo(id: id, documentType: documentType, effectiveDate: effectiveDate)
    }

    private func formattedEffectiveDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "date_form.yyyy_MM_dd".localized()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    func testViewModel_whenPrepare_startObservingTransactionsAndRecoverUnfinished() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.prepare()

        // then
        XCTAssertEqual(self.spyBillingUsecase.didStartObservingTimes, 1)
        XCTAssertEqual(self.spyBillingUsecase.didRecoverUnfinishedTimes, 1)
    }

    func testViewModel_whenWillEnterForeground_notRestartObservingTransactions() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()
        viewModel.prepare()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )

        // then
        XCTAssertEqual(self.spyBillingUsecase.didStartObservingTimes, 1)
    }

    func testViewModel_whenWillEnterForeground_recoverUnfinishedBillingTransactions() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()
        viewModel.prepare()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )

        // then
        XCTAssertEqual(self.spyBillingUsecase.didRecoverUnfinishedTimes, 2)
    }
    
    func testViewModel_whenPrepare_refreshViewAppearance() {
        // given
        let expect = expectation(description: "prepare시에 viewApeparance refresh")
        let viewModel = self.makeViewModelWithoutPrepare()
        
        // when
        let setting = self.waitFirstOutput(expect, for: self.spyUISettingUsecase.currentCalendarUISeting) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertNotNil(setting)
    }
    
    func testViewModel_whenPrepare_runSyncEventNotifications() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()
        
        // when
        viewModel.prepare()
        
        // then
        XCTAssertEqual(self.spyEventNotificationUsecase.didRunSync, true)
    }
    
    func testViewModel_whenPrepare_runApplyEventTagColor() {
        // given
        let expect = expectation(description: "앱 시작이후 전체 이벤트 태그 컬러 색상 정보 bind")
        let viewModel = self.makeViewModelWithoutPrepare()
        self.spyUISettingUsecase.didAppluEventTagColorCallback = { expect.fulfill() }
        
        // when
        viewModel.prepare()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
        self.spyUISettingUsecase.didAppluEventTagColorCallback = nil
    }
    
    func testViewModel_whenPrepare_prepareGoogleCalendar() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.prepare()

        // then
        XCTAssertEqual(self.spyGoogleCalendarUsecase.didPrepared, true)
    }

    func testViewModel_whenPrepare_prepareAppleCalendar() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.prepare()

        // then
        XCTAssertEqual(self.spyAppleCalendarUsecase.didPrepared, true)
    }
    
    func testViewModel_whenFocusChanged_updateCurrentMonth() {
        // given
        let expect = expectation(description: "update current month")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let months = self.waitOutputs(expect, for: viewModel.currentMonth) {
            viewModel.calendarScene(focusChangedTo: .init(2023, 08, 1, isCurrentYear: true, isCurrentDay: true))
            viewModel.calendarScene(focusChangedTo: .init(2023, 09, 1, isCurrentYear: true, isCurrentDay: false))
            viewModel.calendarScene(focusChangedTo: .init(2023, 10, 1, isCurrentYear: true, isCurrentDay: false))
            viewModel.calendarScene(focusChangedTo: .init(2022, 09, 1, isCurrentYear: false, isCurrentDay: false))
        }
        
        // then
        XCTAssertEqual(months.map { $0.monthText }, ["AUG", "SEP", "OCT", "SEP"])
        XCTAssertEqual(months.map { $0.yearText }, [nil, nil, nil, "2022"])
    }
    
    func testViewModle_whenFocusChanged_updateIsShowReturnToToday() {
        // given
        let expect = expectation(description: "update is show today")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel()
        
        // when
        let isShow = self.waitOutputs(expect, for: viewModel.isShowReturnToToday) {
            viewModel.calendarScene(focusChangedTo: .init(2023, 08, 1, isCurrentYear: true, isCurrentDay: true))
            viewModel.calendarScene(focusChangedTo: .init(2023, 09, 1, isCurrentYear: true, isCurrentDay: false))
            viewModel.calendarScene(focusChangedTo: .init(2023, 10, 1, isCurrentYear: true, isCurrentDay: false))
            viewModel.calendarScene(focusChangedTo: .init(2023, 09, 1, isCurrentYear: true, isCurrentDay: false))
            viewModel.calendarScene(focusChangedTo: .init(2023, 08, 1, isCurrentYear: true, isCurrentDay: true))
            viewModel.calendarScene(focusChangedTo: .init(2023, 08, 2, isCurrentYear: true, isCurrentDay: false))
        }
        
        // then
        XCTAssertEqual(isShow, [false, true, false, true])
    }
    
    // request return to today
    func testViewModel_requestReturnToToday() {
        // given
        let expect = expectation(description: "wait-return to today show")
        let viewModel = self.makeViewModel()
        
        // when
        let _ = self.waitFirstOutput(expect, for: viewModel.isShowReturnToToday) {
            viewModel.calendarScene(focusChangedTo: .init(2023, 09, 1, isCurrentYear: true, isCurrentDay: false))
        }
        viewModel.returnToToday()
        
        // then
        XCTAssertEqual(self.spyRouter.interactor.didFocusMovedToToday, true)
    }
     
    func testViewModel_rouetToEventTypeSettingScene() {
        // given
        let expect = expectation(description: "이벤트 타입 세팅 화면으로 이동")
        let viewModel = self.makeViewModel()
        self.spyRouter.didRouteToEventTypeFilterSetting = {
            expect.fulfill()
        }
        
        // when
        viewModel.moveToEventTypeFilterSetting()
        
        // then
        self.wait(for: [expect], timeout: self.timeout)
    }
    
    func testViewModel_routeToSettingScene() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.moveToSetting()

        // then
        XCTAssertEqual(self.spyRouter.didRouteToSetting, true)
    }

    func testViewModel_whenMoveToPreviousMonth_requestToCalendar() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.moveToPreviousMonth()

        // then
        XCTAssertEqual(self.spyRouter.interactor.didMoveToPreviousMonth, true)
    }

    func testViewModel_whenMoveToNextMonth_requestToCalendar() {
        // given
        let viewModel = self.makeViewModel()

        // when
        viewModel.moveToNextMonth()

        // then
        XCTAssertEqual(self.spyRouter.interactor.didMoveToNextMonth, true)
    }
}

extension MainViewModelImpleTests {
    
    // show migration is need
    func testViewModel_checkIsNeedMigration() {
        // given
        let expect = expectation(description: "show migration is need")
        let viewModel = self.makeViewModel()
        
        // when
        let status = self.waitFirstOutput(expect, for: viewModel.temporaryUserDataMigrationStatus)
        
        // then
        XCTAssertEqual(status, .need(100))
    }
    
    // success
    func testViewModel_migrationSuccess() {
        // given
        let expect = expectation(description: "migration success")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let statuses = self.waitOutputs(expect, for: viewModel.temporaryUserDataMigrationStatus) {
            viewModel.handleMigration()
        }
        
        // then
        XCTAssertEqual(statuses, [.need(100), .migrating, nil])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage != nil, true)
    }
    
    // fail
    func testViewModel_migrationFailed() {
        // given
        let expect = expectation(description: "migration failed")
        expect.expectedFulfillmentCount = 4
        let viewModel = self.makeViewModel(shouldFailMigration: true)
        
        // when
        let statuses = self.waitOutputs(expect, for: viewModel.temporaryUserDataMigrationStatus) {
            viewModel.handleMigration()
        }
        
        // then
        XCTAssertEqual(statuses, [.need(100), .migrating, nil, .need(10)])
        XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
    }
}

extension MainViewModelImpleTests {
    
    func testViewModel_notifyRefreshingCalendarEvent() {
        // given
        let expect = expectation(description: "캘린더 이벤트 갱신중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let isLoadings = self.waitOutputs(expect, for: viewModel.isLoadingCalendarEvents) {
            
            self.stubSyncUsecase.sync()
        }
        
        // then
        XCTAssertEqual(isLoadings, [false, true, false])
    }

    func testViewModel_whenFullSyncing_notifyLoadingAllEvents() {
        // given
        let expect = expectation(description: "전체 sync 중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(fullSyncing: true)

        // when
        let isLoadings = self.waitOutputs(expect, for: viewModel.isLoadingAllEvents) {
            self.stubSyncUsecase.sync()
        }

        // then
        XCTAssertEqual(isLoadings, [false, true, false])
    }

    func testViewModel_whenIncrementalSyncing_notNotifyLoadingAllEvents() {
        // given
        let expect = expectation(description: "증분 sync 중에는 전체 sync 안내를 하지 않음")
        expect.expectedFulfillmentCount = 1
        let viewModel = self.makeViewModel()

        // when
        let isLoadings = self.waitOutputs(expect, for: viewModel.isLoadingAllEvents) {
            self.stubSyncUsecase.sync()
        }

        // then
        XCTAssertEqual(isLoadings, [false])
    }
}

extension MainViewModelImpleTests {

    func testViewModel_jumpDay() {
        // given
        let viewModel = self.makeViewModel()
        viewModel.calendarScene(
            focusChangedTo: .init(2023, 07, 23, isCurrentYear: true, isCurrentDay: true)
        )
        
        // when
        viewModel.jumpDate()
        viewModel.daySelectDialog(
            didSelect: .init(2021, 02, 03, isCurrentYear: false, isCurrentDay: false)
        )
        
        // then
        XCTAssertEqual(self.spyRouter.didShowJumpDaySelectDialogWith != nil, true)
        XCTAssertEqual(
            self.spyRouter.interactor.didRequestMoveDay, .init(2021, 02, 03)
        )
    }
}

extension MainViewModelImpleTests {
    
    private class SpyRouter: BaseSpyRouter, MainRouting, @unchecked Sendable {
        
        var interactor = SpyCalendarInteractor()
        var didCalendarAttached: (() -> Void)?
        func attachCalendar() -> (any CalendarSceneInteractor)? {
            self.didCalendarAttached?()
            return self.interactor
        }
        
        var didRouteToEventTypeFilterSetting: (() -> Void)?
        func routeToEventTypeFilterSetting() {
            self.didRouteToEventTypeFilterSetting?()
        }
        
        var didRouteToSetting: Bool?
        func routeToSettingScene() {
            self.didRouteToSetting = true
        }
        
        var didShowJumpDaySelectDialogWith: CalendarDay?
        func showJumpDaySelectDialog(current: CalendarDay) {
            self.didShowJumpDaySelectDialogWith = current
        }
    }
    
    private class SpyCalendarInteractor: CalendarSceneInteractor, @unchecked Sendable {
        
        var didFocusMovedToToday: Bool?
        func moveFocusToToday() {
            self.didFocusMovedToToday = true
        }

        var didMoveToPreviousMonth: Bool?
        func moveToPreviousMonth() {
            self.didMoveToPreviousMonth = true
        }

        var didMoveToNextMonth: Bool?
        func moveToNextMonth() {
            self.didMoveToNextMonth = true
        }

        var didRequestMoveDay: CalendarDay?
        func moveDay(_ day: CalendarDay, withClearPresented: Bool) {
            self.didRequestMoveDay = day
        }

        func requestAIEntry() { }
    }

    private final class SpyEventNotificationUsecase: EventNotificationUsecase, @unchecked Sendable {

        var didRunSync: Bool = false
        func runSyncEventNotification() {
            self.didRunSync = true
        }
    }

    final class SpyEventLiveActivityUsecase: EventLiveActivityUsecase, @unchecked Sendable {

        var didPrepare: Bool = false
        var didHandleWillEnterForeground: Bool = false
        var didStop: Bool = false
        var whenDidPrepare: (() -> Void)?
        var whenDidHandleWillEnterForeground: (() -> Void)?

        func startActivity(_ target: LiveActivityTarget) async throws { }

        func stopActivity() async {
            self.didStop = true
        }

        func prepare() async {
            self.didPrepare = true
            self.whenDidPrepare?()
        }

        func handleWillEnterForeground() async {
            self.didHandleWillEnterForeground = true
            self.whenDidHandleWillEnterForeground?()
        }

        var registeredTarget: AnyPublisher<LiveActivityTarget?, Never> {
            return Empty().eraseToAnyPublisher()
        }
    }

    private final class SpyBillingUsecase: BillingUsecase, @unchecked Sendable {

        var didRecoverUnfinishedTimes: Int = 0
        func recoverUnfinishedTransactions() {
            self.didRecoverUnfinishedTimes += 1
        }

        var didStartObservingTimes: Int = 0
        func startObservingTransactions() {
            self.didStartObservingTimes += 1
        }

        func loadPlanOfferings() async throws -> [BillingPlanOffering] { return [] }
        func loadTopupOfferings() async throws -> [BillingTopupOffering] { return [] }
        func purchase(productId: String) async throws -> BillingPurchaseResult { return .cancelled }
        func restorePurchases() async throws -> BillingRestoreResult { return .nothingToRestore }
        func refreshUserPlan() async throws -> BillingUserPlan { return BillingUserPlan() }
        func stopObservingTransactions() { }
        func hasUnfinishedTransactions() async -> Bool { return false }
        func applyUnfinishedTransactions() async throws -> BillingUserPlan? { return nil }
        func latestUserPlan() -> BillingUserPlan? { return nil }

        var currentUserPlan: AnyPublisher<BillingUserPlan, Never> {
            return Empty().eraseToAnyPublisher()
        }
    }

    private final class StubLegalNoticeUsecase: LegalNoticeUsecase, @unchecked Sendable {

        private let updatesSubject = CurrentValueSubject<[LegalNoticeUpdateInfo], Never>([])
        var didCheckNoticeIsNeed: Bool = false
        var didConfirmNoticeWithDocumentType: LegalDocumentType?

        func checkNoticeIsNeed() {
            self.didCheckNoticeIsNeed = true
        }

        var pendingNoticeUpdates: AnyPublisher<[LegalNoticeUpdateInfo], Never> {
            return self.updatesSubject.eraseToAnyPublisher()
        }

        func confirmNotice(_ documentType: LegalDocumentType) {
            self.didConfirmNoticeWithDocumentType = documentType
            self.updatesSubject.send(
                self.updatesSubject.value.filter { $0.documentType != documentType }
            )
        }

        func sendUpdates(_ updates: [LegalNoticeUpdateInfo]) {
            self.updatesSubject.send(updates)
        }
    }
}


// MARK: - AI job 갱신

extension MainViewModelImpleTests {

    func testViewModel_whenEnterForeground_refreshProcessingAIJob() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )

        // then
        XCTAssertEqual(self.stubAIOrchestrationUsecase.didRefreshProcessingJob, true)
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenNotEnterForeground_notRefreshProcessingAIJob() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when

        // then
        XCTAssertNil(self.stubAIOrchestrationUsecase.didRefreshProcessingJob)
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenHandleAIJobStatusChanged_passToOrchestrationUsecase() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.handleAIJobStatusChanged("some_job")

        // then
        XCTAssertEqual(
            self.stubAIOrchestrationUsecase.didHandleJobStatusChangedWith, "some_job"
        )
    }

    func testViewModel_whenEnterForeground_refreshAIUsage() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )

        // then
        XCTAssertEqual(self.stubAIOrchestrationUsecase.didLoadUsage, true)
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenNotEnterForeground_notRefreshAIUsage() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when

        // then
        XCTAssertNil(self.stubAIOrchestrationUsecase.didLoadUsage)
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenEnterForeground_refreshNotificationPermissionStatus() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )

        // then
        XCTAssertEqual(self.stubAIOrchestrationUsecase.didRefreshNotificationPermissionStatus, true)
        withExtendedLifetime(viewModel) { }
    }

    func testViewModel_whenNotEnterForeground_notRefreshNotificationPermissionStatus() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when

        // then
        XCTAssertNil(self.stubAIOrchestrationUsecase.didRefreshNotificationPermissionStatus)
        withExtendedLifetime(viewModel) { }
    }
}


// MARK: - 라이브액티비티

extension MainViewModelImpleTests {

    func testViewModel_whenPrepare_prepareLiveActivity() {
        // given
        let expect = expectation(description: "prepare 시 라이브액티비티 복원이 걸린다")
        let viewModel = self.makeViewModelWithoutPrepare()
        self.spyEventLiveActivityUsecase.whenDidPrepare = { expect.fulfill() }

        // when
        viewModel.prepare()

        // then
        self.wait(for: [expect], timeout: 0.1)
        self.spyEventLiveActivityUsecase.whenDidPrepare = nil
        XCTAssertEqual(self.spyEventLiveActivityUsecase.didPrepare, true)
    }

    func testViewModel_whenWillEnterForeground_reconcileLiveActivity() {
        // given
        let expect = expectation(description: "포그라운드 복귀 시 등록 상태를 재조정한다")
        let viewModel = self.makeViewModelWithoutPrepare()
        viewModel.prepare()
        self.spyEventLiveActivityUsecase.whenDidHandleWillEnterForeground = { expect.fulfill() }

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )

        // then
        self.wait(for: [expect], timeout: 0.1)
        self.spyEventLiveActivityUsecase.whenDidHandleWillEnterForeground = nil
        XCTAssertEqual(self.spyEventLiveActivityUsecase.didHandleWillEnterForeground, true)
    }
}


// MARK: - 안내할일

extension MainViewModelImpleTests {

    func testViewModel_whenPrepare_prepareGuideTodo() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.prepare()

        // then
        XCTAssertEqual(self.stubGuideTodoUsecase.didPrepare, true)
    }
}


// MARK: - 고지 배너

extension MainViewModelImpleTests {

    func testViewModel_whenTwoPendingUpdates_emitsTwoBannerModelsInOrder() {
        // given
        let expect = expectation(description: "미확인 문서 2건 -> 배너 모델 2건")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        let modelLists = self.waitOutputs(expect, for: viewModel.legalNoticeBanners) {
            self.stubLegalNoticeUsecase.sendUpdates([
                self.makeUpdateInfo(id: "terms_1", documentType: .terms),
                self.makeUpdateInfo(id: "privacy_1", documentType: .privacy)
            ])
        }

        // then
        let models = modelLists.last
        let expectedEffectiveDateText = "legal_notice.effectiveDate".localized(
            with: self.formattedEffectiveDate(Date(timeIntervalSince1970: 1_700_000_000))
        )
        XCTAssertEqual(models?.map { $0.documentType }, [.terms, .privacy])
        XCTAssertEqual(models?.map { $0.message }, [
            "legal_notice.message::terms".localized(),
            "legal_notice.message::privacy".localized()
        ])
        XCTAssertEqual(models?.map { $0.effectiveDateText }, [
            expectedEffectiveDateText, expectedEffectiveDateText
        ])
    }

    func testViewModel_whenOnePendingUpdate_emitsOneBannerModel() {
        // given
        let expect = expectation(description: "미확인 문서 1건 -> 배너 모델 1건")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        let modelLists = self.waitOutputs(expect, for: viewModel.legalNoticeBanners) {
            self.stubLegalNoticeUsecase.sendUpdates([
                self.makeUpdateInfo(documentType: .privacy)
            ])
        }

        // then
        let models = modelLists.last
        XCTAssertEqual(models?.map { $0.documentType }, [.privacy])
        XCTAssertEqual(models?.map { $0.message }, [
            "legal_notice.message::privacy".localized()
        ])
    }

    func testViewModel_whenNoPendingUpdates_emitsEmptyArray() {
        // given
        let expect = expectation(description: "미확인 문서가 없으면 빈 배열 방출")
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        let models = self.waitFirstOutput(expect, for: viewModel.legalNoticeBanners)

        // then
        XCTAssertEqual(models, [])
    }

    func testViewModel_whenOpenDocument_showsWebViewForThatDocumentOnly() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.openLegalNoticeDocument(.privacy)

        // then
        XCTAssertEqual(self.spyRouter.didShowWebViewPath, LegalDocumentType.privacy.linkPath)
        XCTAssertNil(self.spyRouter.didShowActionSheetWith)
    }

    func testViewModel_whenCloseBanner_confirmsThatDocumentOnly() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.closeLegalNoticeBanner(.terms)

        // then
        XCTAssertEqual(self.stubLegalNoticeUsecase.didConfirmNoticeWithDocumentType, .terms)
    }

    func testViewModel_whenPrepare_checkLegalNotice() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        viewModel.prepare()

        // then
        XCTAssertEqual(self.stubLegalNoticeUsecase.didCheckNoticeIsNeed, true)
    }

    func testViewModel_whenWillEnterForeground_checkLegalNotice() {
        // given
        let viewModel = self.makeViewModelWithoutPrepare()

        // when
        NotificationCenter.default.post(
            name: UIApplication.willEnterForegroundNotification, object: nil
        )

        // then
        XCTAssertEqual(self.stubLegalNoticeUsecase.didCheckNoticeIsNeed, true)
        withExtendedLifetime(viewModel) { }
    }
}
