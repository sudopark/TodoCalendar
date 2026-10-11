//
//  AdBannerUIView.swift
//  AdService
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine
import GoogleMobileAds
import Domain
import Extensions


public final class AdBannerUIView: UIView {

    private let size: AdBannerSize
    private let bannerView: BannerView
    private let onVisibleHeightChange: (@MainActor (CGFloat) -> Void)?
    private var isLoaded: Bool = false
    private var isAllowed: Bool = false
    private var isLoadingAd: Bool = false
    private lazy var heightConstraint: NSLayoutConstraint = self.heightAnchor.constraint(equalToConstant: 0)
    private let cancellables = CancelBag()

    public init(
        adUnitId: String,
        size: AdBannerSize,
        adExposureUsecase: any AdExposureUsecase,
        onVisibleHeightChange: (@MainActor (CGFloat) -> Void)? = nil
    ) {
        self.size = size
        self.bannerView = BannerView(adSize: AdSizeInvalid)
        self.onVisibleHeightChange = onVisibleHeightChange
        super.init(frame: .zero)

        self.bannerView.adUnitID = adUnitId
        self.bannerView.delegate = self
        self.heightConstraint.isActive = true
        self.bindLoadWhenBannerAdAllowed(adExposureUsecase)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard let adSize = self.size.adSize(
                fittingWidth: self.bounds.width,
                within: self.window?.screen.bounds.size ?? .zero
              ),
              isAdSizeEqualToSize(size1: self.bannerView.adSize, size2: adSize) == false
        else { return }
        // 광고가 떠 있는 동안 adSize 를 바꾸면 SDK 가 새 크기로 다시 요청한다 — load 를 겹쳐 부르지 않는다
        self.bannerView.adSize = adSize
        self.invalidateIntrinsicContentSize()
        self.applyVisibleHeight()
        self.loadIfNeeded()
    }

    // SwiftUI 경로엔 폭 제약이 없어 이 값이 MREC 폭을 정한다
    public override var intrinsicContentSize: CGSize {
        guard self.hasValidAdSize else { return .zero }
        return cgSize(for: self.bannerView.adSize)
    }

    private var hasValidAdSize: Bool {
        return isAdSizeValid(size: self.bannerView.adSize)
    }

    private var visibleHeight: CGFloat {
        guard self.isLoaded, self.isAllowed, self.hasValidAdSize else { return 0 }
        return cgSize(for: self.bannerView.adSize).height
    }

    private func applyVisibleHeight() {
        self.heightConstraint.constant = self.visibleHeight
        self.onVisibleHeightChange?(self.visibleHeight)
    }

    private func bindLoadWhenBannerAdAllowed(_ adExposureUsecase: any AdExposureUsecase) {
        adExposureUsecase.isBannerAdAllowed
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isAllowed in
                self?.apply(isAllowed: isAllowed)
            })
            .store(in: self.cancellables)
    }

    private func apply(isAllowed: Bool) {
        self.isAllowed = isAllowed
        self.bannerView.isHidden = !isAllowed
        self.applyVisibleHeight()
        self.loadIfNeeded()
    }

    private func loadIfNeeded() {
        guard self.isAllowed,
              self.isLoaded == false,
              self.isLoadingAd == false,
              self.hasValidAdSize
        else { return }
        self.isLoadingAd = true
        self.bannerView.load(Request())
    }
}


// MARK: - BannerViewDelegate

extension AdBannerUIView: BannerViewDelegate {

    public func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        self.isLoadingAd = false
        if self.isLoaded == false {
            self.isLoaded = true
            self.bannerView.isHidden = !self.isAllowed

            // 로드에 성공한 뒤에야 계층에 붙어 실패한 배너가 자리를 차지하지 않는다
            self.addSubview(bannerView)
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            let bottom = bannerView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            bottom.priority = .defaultHigh
            NSLayoutConstraint.activate([
                bannerView.topAnchor.constraint(equalTo: self.topAnchor),
                bannerView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                bottom
            ])
        }
        self.applyVisibleHeight()
    }

    public func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: any Error
    ) {
        logger.log(level: .error, "banner ad load failed: \(error)")
        self.isLoadingAd = false
    }
}


// MARK: - AdBannerView

public struct AdBannerView: View {

    private let adUnitId: String
    private let size: AdBannerSize
    private let adExposureUsecase: any AdExposureUsecase
    @State private var visibleHeight: CGFloat = 0

    public init(
        adUnitId: String,
        size: AdBannerSize,
        adExposureUsecase: any AdExposureUsecase
    ) {
        self.adUnitId = adUnitId
        self.size = size
        self.adExposureUsecase = adExposureUsecase
    }

    public var body: some View {
        BannerRepresentable(
            adUnitId: self.adUnitId,
            size: self.size,
            adExposureUsecase: self.adExposureUsecase,
            visibleHeight: self.$visibleHeight
        )
        .frame(height: self.visibleHeight)
    }
}

private struct BannerRepresentable: UIViewRepresentable {

    let adUnitId: String
    let size: AdBannerSize
    let adExposureUsecase: any AdExposureUsecase
    @Binding var visibleHeight: CGFloat

    func makeUIView(context: Context) -> AdBannerUIView {
        return AdBannerUIView(
            adUnitId: self.adUnitId,
            size: self.size,
            adExposureUsecase: self.adExposureUsecase,
            onVisibleHeightChange: { self.visibleHeight = $0 }
        )
    }

    func updateUIView(_ uiView: AdBannerUIView, context: Context) { }
}
