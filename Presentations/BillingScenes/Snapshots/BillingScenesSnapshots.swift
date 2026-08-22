//
//  BillingScenesSnapshots.swift
//  BillingScenes
//
//  Created by sudo.park on 8/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import XCTest
import SwiftUI
import Domain
import Extensions
import CommonPresentation
import SnapshotTestHelpKit

@testable import BillingScenes


final class BillingScenesSnapshots: XCTestCase {

    @MainActor
    private func makeAppearance(_ theme: SnapshotTheme) -> ViewAppearance {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: theme.isSystemDarkTheme ? .defaultDark : .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        return ViewAppearance(setting: setting, isSystemDarkTheme: theme.isSystemDarkTheme)
    }

    // PaywallView는 private이라 ContainerView(공개 인터페이스)로만 캡처 가능. VM 없이 state를
    // stateBinding 훅(프로덕션에서도 ViewController가 `{ $0.bind(viewModel) }`로 쓰는 자리)으로
    // 직접 채운다 — Combine을 거치지 않는 동기 대입이라 CalendarScenesSnapshots처럼 RunLoop pump가
    // 필요 없다.
    @MainActor
    private func makePaywallView(
        _ theme: SnapshotTheme, configure: @escaping (PaywallViewState) -> Void
    ) -> some View {
        var container = PaywallContainerView(
            viewAppearance: self.makeAppearance(theme),
            eventHandlers: PaywallViewEventHandler()
        )
        container.stateBinding = configure
        return container
    }

    private func cell(
        _ planId: BillingPlanId,
        price: String?,
        period: String?,
        dailyLimit: Int,
        isOwned: Bool,
        isCovered: Bool,
        isRecommended: Bool = false
    ) -> PaywallPlanCellModel {
        return PaywallPlanCellModel(
            planId: planId,
            name: planId.name,
            priceText: price,
            periodText: period,
            metricText: "billing::paywall::metric::dailyCredits".localized(with: "\(dailyLimit)"),
            isOwned: isOwned,
            isCovered: isCovered,
            isRecommended: isRecommended
        )
    }

    private func detail(
        planId: BillingPlanId,
        dailyLimit: Int,
        isTopupAllowed: Bool,
        disclosureKey: String,
        ctaKey: String
    ) -> PaywallPlanDetailModel {
        return PaywallPlanDetailModel(
            sectionTitle: "billing::paywall::features::title".localized(with: planId.name),
            features: [
                "billing::paywall::feature::dailyCredits".localized(with: "\(dailyLimit)"),
                isTopupAllowed ? "billing::paywall::feature::topup".localized() : nil,
                "billing::paywall::feature::noAds".localized()
            ].compactMap { $0 },
            disclosure: disclosureKey.localized(),
            ctaTitle: ctaKey.localized(with: planId.name)
        )
    }

    private func topupCell(
        credits: Int, price: String, bonusPercent: Int? = nil
    ) -> PaywallTopupCellModel {
        return PaywallTopupCellModel(
            productId: "topup.tier.\(credits)",
            creditsText: "billing::paywall::topup::credits".localized(with: credits.formatted()),
            priceText: price,
            bonusText: bonusPercent.map {
                "billing::paywall::topup::bonus".localized(with: "\($0)")
            }
        )
    }
}


// MARK: - 무료 유저 — 구매 가능 카드 전부 노출

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallFreeUser() {
        captureSnapshotPair(named: "paywallFreeUser", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .free
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "20")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.cellModels = [
                    self.cell(
                        .standard, price: "$4.99",
                        period: "billing::paywall::period::monthly".localized(),
                        dailyLimit: 200, isOwned: false, isCovered: false, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: "$49.99", period: nil,
                        dailyLimit: 500, isOwned: false, isCovered: false
                    )
                ]
                state.selectedPlanId = .standard
                state.selectedPlanDetail = self.detail(
                    planId: .standard, dailyLimit: 200, isTopupAllowed: true,
                    disclosureKey: "billing::paywall::disclosure::subscription",
                    ctaKey: "billing::paywall::cta::subscribe"
                )
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 스탠다드 보유 — 해당 카드 보유 배지, lifetime은 구매 가능

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallStandardOwned() {
        captureSnapshotPair(named: "paywallStandardOwned", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .standard
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "200")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.cellModels = [
                    self.cell(
                        .standard, price: "$4.99",
                        period: "billing::paywall::period::monthly".localized(),
                        dailyLimit: 200, isOwned: true, isCovered: true, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: "$49.99", period: nil,
                        dailyLimit: 500, isOwned: false, isCovered: false
                    )
                ]
                state.selectedPlanId = .lifetime
                state.selectedPlanDetail = self.detail(
                    planId: .lifetime, dailyLimit: 500, isTopupAllowed: true,
                    disclosureKey: "billing::paywall::disclosure::oneTime",
                    ctaKey: "billing::paywall::cta::buy"
                )
                state.showsManageSubscription = true
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 평생 보유 — 구매 가능 카드 없음, CTA 비활성

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallLifetimeOwned() {
        captureSnapshotPair(named: "paywallLifetimeOwned", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .lifetime
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "500")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.cellModels = [
                    self.cell(
                        .standard, price: "$4.99",
                        period: "billing::paywall::period::monthly".localized(),
                        dailyLimit: 200, isOwned: false, isCovered: true, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: "$49.99", period: nil,
                        dailyLimit: 500, isOwned: true, isCovered: true
                    )
                ]
                // 커버되지 않은 카드가 없다 — 선택도 상세도 없이 "이미 최고 플랜" 안내로 대체된다
                state.selectedPlanId = nil
                state.selectedPlanDetail = nil
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 카탈로그 로딩 중

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallLoading() {
        captureSnapshotPair(named: "paywallLoading", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = nil
                state.currentPlanDescription = ""
                state.catalogState = .loading
                state.screenState = .ready(state.catalogState)
                state.cellModels = []
                state.selectedPlanId = nil
                state.selectedPlanDetail = nil
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 스토어 가격 조회 실패 — 서버 카탈로그는 로드됐지만 StoreKit 상품 조회가 실패해
// 가격만 대체 문구, CTA 비활성 (catalogState 는 .loaded — .failed 와는 다른 상태다, I5)

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallStoreUnavailable() {
        captureSnapshotPair(named: "paywallStoreUnavailable", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .free
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "20")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.cellModels = [
                    self.cell(
                        .standard, price: nil,
                        period: nil,
                        dailyLimit: 200, isOwned: false, isCovered: false, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: nil, period: nil,
                        dailyLimit: 500, isOwned: false, isCovered: false
                    )
                ]
                // 가격이 없어 두 카드 모두 구매 불가(isPurchasable == false) — 선택도 상세도 없다
                state.selectedPlanId = nil
                state.selectedPlanDetail = nil
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 구매 진행 중 — CTA isProcessing

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallPurchasing() {
        captureSnapshotPair(named: "paywallPurchasing", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .free
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "20")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.cellModels = [
                    self.cell(
                        .standard, price: "$4.99",
                        period: "billing::paywall::period::monthly".localized(),
                        dailyLimit: 200, isOwned: false, isCovered: false, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: "$49.99", period: nil,
                        dailyLimit: 500, isOwned: false, isCovered: false
                    )
                ]
                state.selectedPlanId = .standard
                state.selectedPlanDetail = self.detail(
                    planId: .standard, dailyLimit: 200, isTopupAllowed: true,
                    disclosureKey: "billing::paywall::disclosure::subscription",
                    ctaKey: "billing::paywall::cta::subscribe"
                )
                state.isPurchasing = true
            }
        }
    }
}


// MARK: - 미완료 결제 있음 — CTA 위 고정 복구 배너 (#812)

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallUnfinishedRecovery() {
        captureSnapshotPair(named: "paywallUnfinishedRecovery", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .free
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "20")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.cellModels = [
                    self.cell(
                        .standard, price: "$4.99",
                        period: "billing::paywall::period::monthly".localized(),
                        dailyLimit: 200, isOwned: false, isCovered: false, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: "$49.99", period: nil,
                        dailyLimit: 500, isOwned: false, isCovered: false
                    )
                ]
                state.selectedPlanId = .standard
                state.selectedPlanDetail = self.detail(
                    planId: .standard, dailyLimit: 200, isTopupAllowed: true,
                    disclosureKey: "billing::paywall::disclosure::subscription",
                    ctaKey: "billing::paywall::cta::subscribe"
                )
                state.hasUnfinishedTransactions = true
            }
        }
    }
}


// MARK: - 서버 카탈로그 요청 실패 — catalogState == .failed, accentWarn 안내 문구로 대체 (I5)

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallCatalogLoadFailed() {
        captureSnapshotPair(named: "paywallCatalogLoadFailed", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .free
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "20")
                state.catalogState = .failed
                state.screenState = .ready(state.catalogState)
                state.cellModels = []
                state.selectedPlanId = nil
                state.selectedPlanDetail = nil
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 유저 플랜 조회 게이트 로딩 중 — screenState == .loading, 본문 전체가 스피너로 대체 (#739)

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallUserPlanLoading() {
        captureSnapshotPair(named: "paywallUserPlanLoading", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = nil
                state.currentPlanDescription = ""
                state.catalogState = .loading
                state.screenState = .loading
                state.cellModels = []
                state.selectedPlanId = nil
                state.selectedPlanDetail = nil
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 유저 플랜 조회 실패 — screenState == .userPlanLoadFailed, 본문(플랜 카드·CTA·고지문)
// 없이 전면 에러 안내 + 재시도 버튼으로 대체 (#739)

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallUserPlanLoadFailed() {
        captureSnapshotPair(named: "paywallUserPlanLoadFailed", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = nil
                state.currentPlanDescription = ""
                state.catalogState = .loading
                state.screenState = .userPlanLoadFailed
                state.cellModels = []
                state.selectedPlanId = nil
                state.selectedPlanDetail = nil
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 유료 플랜 보유 — top-up 섹션 노출

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallTopupAvailable() {
        captureSnapshotPair(named: "paywallTopupAvailable", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .standard
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "200")
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.showsManageSubscription = true
                state.cellModels = [
                    self.cell(
                        .standard, price: "$4.99",
                        period: "billing::paywall::period::monthly".localized(),
                        dailyLimit: 200, isOwned: true, isCovered: true, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: "$49.99", period: nil,
                        dailyLimit: 500, isOwned: false, isCovered: false
                    )
                ]
                state.selectedPlanId = .lifetime
                state.selectedPlanDetail = self.detail(
                    planId: .lifetime, dailyLimit: 500, isTopupAllowed: true,
                    disclosureKey: "billing::paywall::disclosure::oneTime",
                    ctaKey: "billing::paywall::cta::buy"
                )
                state.topupCellModels = [
                    self.topupCell(credits: 30000, price: "$0.99"),
                    self.topupCell(credits: 165000, price: "$4.99", bonusPercent: 10),
                    self.topupCell(credits: 432000, price: "$9.99", bonusPercent: 20)
                ]
                state.topupTitle = "billing::paywall::topup::title".localized()
                state.isPurchasing = false
            }
        }
    }
}


// MARK: - 하향 예약 상태 — 현재 플랜 아래에 안내

extension BillingScenesSnapshots {

    @MainActor
    func test_paywallScheduledChange() {
        captureSnapshotPair(named: "paywallScheduledChange", layout: .fullScreen) { theme in
            self.makePaywallView(theme) { state in
                state.currentPlan = .standard
                state.currentPlanDescription = "billing::paywall::current::description".localized(with: "200")
                state.scheduledChange = BillingUserPlan.ScheduledChange(
                    planId: .free, effectiveAt: Date(timeIntervalSince1970: 1786000000)
                )
                state.catalogState = .loaded([])
                state.screenState = .ready(state.catalogState)
                state.showsManageSubscription = true
                state.cellModels = [
                    self.cell(
                        .standard, price: "$4.99",
                        period: "billing::paywall::period::monthly".localized(),
                        dailyLimit: 200, isOwned: true, isCovered: true, isRecommended: true
                    ),
                    self.cell(
                        .lifetime, price: "$49.99", period: nil,
                        dailyLimit: 500, isOwned: false, isCovered: false
                    )
                ]
                state.selectedPlanId = .lifetime
                state.selectedPlanDetail = self.detail(
                    planId: .lifetime, dailyLimit: 500, isTopupAllowed: true,
                    disclosureKey: "billing::paywall::disclosure::oneTime",
                    ctaKey: "billing::paywall::cta::buy"
                )
                state.topupCellModels = [
                    self.topupCell(credits: 30000, price: "$0.99"),
                    self.topupCell(credits: 165000, price: "$4.99", bonusPercent: 10),
                    self.topupCell(credits: 432000, price: "$9.99", bonusPercent: 20)
                ]
                state.topupTitle = "billing::paywall::topup::title".localized()
                state.isPurchasing = false
            }
        }
    }
}
