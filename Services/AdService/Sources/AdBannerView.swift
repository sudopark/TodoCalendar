//
//  AdBannerView.swift
//  AdService
//
//  Created by sudo.park on 8/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import UIKit
import SwiftUI


public struct AdBannerView: View {

    private let adUnitId: String
    private let size: AdBannerSize
    private let adService: GoogleMobileAdsServiceImple
    @State private var isLoaded: Bool = false

    public init(
        adUnitId: String,
        size: AdBannerSize,
        adService: GoogleMobileAdsServiceImple
    ) {
        self.adUnitId = adUnitId
        self.size = size
        self.adService = adService
    }

    public var body: some View {
        // SwiftUI 는 UIView 쪽 intrinsic size 무효화를 다시 재보지 않는다 — 높이를 상태로 가른다
        BannerRepresentable(
            adUnitId: self.adUnitId,
            size: self.size,
            adService: self.adService,
            isLoaded: self.$isLoaded
        )
        .frame(height: self.isLoaded ? self.size.asCGSize.height : 0)
    }
}

private struct BannerRepresentable: UIViewRepresentable {

    let adUnitId: String
    let size: AdBannerSize
    let adService: GoogleMobileAdsServiceImple
    @Binding var isLoaded: Bool

    func makeUIView(context: Context) -> AdBannerUIView {
        return AdBannerUIView(
            adUnitId: self.adUnitId,
            size: self.size,
            adService: self.adService,
            onLoad: { self.isLoaded = true }
        )
    }

    func updateUIView(_ uiView: AdBannerUIView, context: Context) { }
}
