//
//  AdBannerUIView.swift
//  AdService
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import Combine
import GoogleMobileAds
import Extensions
import Domain


public final class AdBannerUIView: UIView {

    private let bannerView: BannerView
    private let onVisibilityChange: (@MainActor (Bool) -> Void)?
    private var isLoaded: Bool = false
    private var isAllowed: Bool = false
    private var didRequestLoad: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    public init(
        adUnitId: String,
        size: AdBannerSize,
        adService: GoogleMobileAdsServiceImple,
        billingUsecase: any BillingUsecase,
        onVisibilityChange: (@MainActor (Bool) -> Void)? = nil
    ) {
        self.bannerView = BannerView(adSize: size.asAdSize)
        self.onVisibilityChange = onVisibilityChange
        super.init(frame: .zero)

        self.bannerView.adUnitID = adUnitId
        self.bannerView.delegate = self
        self.bindLoadWhenFreePlanConfirmed(adService, billingUsecase)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isVisible: Bool { self.isLoaded && self.isAllowed }

    public override var intrinsicContentSize: CGSize {
        guard self.isVisible else { return .zero }
        return cgSize(for: self.bannerView.adSize)
    }

    // currentUserPlan 이 무방출이면 CombineLatest 도 무방출이라 자연히 fail-closed 다.
    // .first() 를 안 쓰는 이유는 세션 중 유료 전환 시 배너를 내려야 해서다.
    private func bindLoadWhenFreePlanConfirmed(
        _ adService: GoogleMobileAdsServiceImple,
        _ billingUsecase: any BillingUsecase
    ) {
        Publishers.CombineLatest(adService.isStarted, billingUsecase.currentUserPlan)
            .map { isStarted, userPlan in isStarted && userPlan.planId == .free }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isAllowed in
                self?.apply(isAllowed: isAllowed)
            })
            .store(in: &self.cancellables)
    }

    private func apply(isAllowed: Bool) {
        self.isAllowed = isAllowed
        // 소비자가 명시 높이 제약을 걸어도 새어나가지 않게 intrinsic size 와 별도로 직접 숨긴다
        self.bannerView.isHidden = !isAllowed
        self.invalidateIntrinsicContentSize()
        self.onVisibilityChange?(self.isVisible)
        guard isAllowed, self.didRequestLoad == false else { return }
        self.didRequestLoad = true
        self.bannerView.load(Request())
    }
}


// MARK: - BannerViewDelegate

extension AdBannerUIView: BannerViewDelegate {

    // 로드에 성공한 뒤에야 계층에 붙어 실패한 배너가 자리를 차지하지 않는다
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard self.isLoaded == false else { return }
        self.isLoaded = true
        self.bannerView.isHidden = !self.isAllowed

        self.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: self.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        self.invalidateIntrinsicContentSize()
        self.onVisibilityChange?(self.isVisible)
    }
    
    public func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: any Error
    ) {
        logger.log(level: .error, "banner ad load failed: \(error)")
    }
}
