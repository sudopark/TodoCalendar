//
//  GatedAdBannerViews.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI
import Combine


final class GatedAdBannerUIView: UIView {

    private let makeBanner: @MainActor () -> UIView
    private var bannerView: UIView?
    private var cancellable: AnyCancellable?

    init(canShowAd: AnyPublisher<Bool, Never>, makeBanner: @escaping @MainActor () -> UIView) {
        self.makeBanner = makeBanner
        super.init(frame: .zero)
        self.bind(canShowAd)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        guard self.bannerView != nil else { return .zero }
        return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    private func bind(_ canShowAd: AnyPublisher<Bool, Never>) {
        self.cancellable = canShowAd
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] canShow in
                self?.applyGateState(canShow)
            }
    }

    private func applyGateState(_ canShow: Bool) {
        self.bannerView?.removeFromSuperview()
        self.bannerView = nil

        if canShow {
            let banner = self.makeBanner()
            banner.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(banner)
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: self.topAnchor),
                banner.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                banner.trailingAnchor.constraint(equalTo: self.trailingAnchor),
                banner.bottomAnchor.constraint(equalTo: self.bottomAnchor)
            ])
            self.bannerView = banner
        }

        self.invalidateIntrinsicContentSize()
    }
}


struct GatedAdBannerView<Banner: View>: View {

    private let canShowAd: AnyPublisher<Bool, Never>
    private let makeBanner: () -> Banner
    @State private var canShow: Bool = false

    init(canShowAd: AnyPublisher<Bool, Never>, makeBanner: @escaping () -> Banner) {
        self.canShowAd = canShowAd
        self.makeBanner = makeBanner
    }

    var body: some View {
        Group {
            if self.canShow {
                self.makeBanner()
            } else {
                EmptyView()
            }
        }
        .onReceive(self.canShowAd.receive(on: RunLoop.main)) { canShow in
            self.canShow = canShow
        }
    }
}
