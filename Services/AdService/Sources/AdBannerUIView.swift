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


public final class AdBannerUIView: UIView {
    
    private let bannerView: BannerView
    private let onLoad: (@MainActor () -> Void)?
    private var isLoaded: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    public init(
        adUnitId: String,
        size: AdBannerSize,
        adService: GoogleMobileAdsServiceImple,
        onLoad: (@MainActor () -> Void)? = nil
    ) {
        self.bannerView = BannerView(adSize: size.asAdSize)
        self.onLoad = onLoad
        super.init(frame: .zero)
        
        self.bannerView.adUnitID = adUnitId
        self.bannerView.delegate = self
        self.bindLoadWhenAdServiceStarted(adService)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: CGSize {
        guard self.isLoaded else { return .zero }
        return cgSize(for: self.bannerView.adSize)
    }
    
    private func bindLoadWhenAdServiceStarted(_ adService: GoogleMobileAdsServiceImple) {
        adService.isStarted
            .filter { $0 }
            .first()
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] _ in
                self?.bannerView.load(Request())
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - BannerViewDelegate

extension AdBannerUIView: BannerViewDelegate {
    
    // 로드에 성공한 뒤에야 계층에 붙어 실패한 배너가 자리를 차지하지 않는다
    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard self.isLoaded == false else { return }
        self.isLoaded = true
        
        self.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: self.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        self.invalidateIntrinsicContentSize()
        self.onLoad?()
    }
    
    public func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: any Error
    ) {
        logger.log(level: .error, "banner ad load failed: \(error)")
    }
}
