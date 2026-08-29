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

    private let bannerView: BannerView
    private let onVisibilityChange: (@MainActor (Bool) -> Void)?
    private var isLoaded: Bool = false
    private var isAllowed: Bool = false
    private var didRequestLoad: Bool = false
    private lazy var heightConstraint: NSLayoutConstraint = self.heightAnchor.constraint(equalToConstant: 0)
    private let cancellables = CancelBag()

    public init(
        adUnitId: String,
        size: AdBannerSize,
        adExposureUsecase: any AdExposureUsecase,
        onVisibilityChange: (@MainActor (Bool) -> Void)? = nil
    ) {
        self.bannerView = BannerView(adSize: size.asAdSize)
        self.onVisibilityChange = onVisibilityChange
        super.init(frame: .zero)

        self.bannerView.adUnitID = adUnitId
        self.bannerView.delegate = self
        self.heightConstraint.isActive = true
        self.bindLoadWhenBannerAdAllowed(adExposureUsecase)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isVisible: Bool { self.isLoaded && self.isAllowed }

    public override var intrinsicContentSize: CGSize {
        return cgSize(for: self.bannerView.adSize)
    }

    private func applyHeight() {
        self.heightConstraint.constant = self.isVisible
            ? cgSize(for: self.bannerView.adSize).height
            : 0
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
        self.applyHeight()
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
        let bottom = bannerView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        bottom.priority = .defaultHigh
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: self.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bottom
        ])
        self.applyHeight()
        self.onVisibilityChange?(self.isVisible)
    }
    
    public func bannerView(
        _ bannerView: BannerView,
        didFailToReceiveAdWithError error: any Error
    ) {
        logger.log(level: .error, "banner ad load failed: \(error)")
    }
}


// MARK: - AdBannerView

public struct AdBannerView: View {

    private let adUnitId: String
    private let size: AdBannerSize
    private let adExposureUsecase: any AdExposureUsecase
    @State private var isVisible: Bool = false

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
            isVisible: self.$isVisible
        )
        .frame(height: self.isVisible ? self.size.asCGSize.height : 0)
    }
}

private struct BannerRepresentable: UIViewRepresentable {

    let adUnitId: String
    let size: AdBannerSize
    let adExposureUsecase: any AdExposureUsecase
    @Binding var isVisible: Bool

    func makeUIView(context: Context) -> AdBannerUIView {
        return AdBannerUIView(
            adUnitId: self.adUnitId,
            size: self.size,
            adExposureUsecase: self.adExposureUsecase,
            onVisibilityChange: { self.isVisible = $0 }
        )
    }

    func updateUIView(_ uiView: AdBannerUIView, context: Context) { }
}
