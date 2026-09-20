//
//  WidgetBackgroundView.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/20/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import CommonPresentation


public struct WidgetBackgroundView: View {

    private enum Constant {
        /// 사진 위에서 글자가 읽히는 농도 — 0/25/35/45% 시안 대조로 정했다 (2026-09-20)
        static let photoScrimOpacity: CGFloat = 0.35
    }

    private let look: WidgetLook
    private let shape: AnyShape

    public init(look: WidgetLook, in shape: some Shape) {
        self.look = look
        self.shape = AnyShape(shape)
    }

    public var body: some View {
        shape
            .fill(WidgetBackgroundStyle(look.background).shape)
            .overlay { photoLayer.clipShape(shape) }
    }

    @ViewBuilder
    private var photoLayer: some View {
        if let photo = look.photo {
            ZStack {
                photoImageView(photo)
                Color.black.opacity(Constant.photoScrimOpacity)
            }
        }
    }

    /// 프레임 없이 scaledToFill 하면 부모가 원본 크기로 늘어나 콘텐츠가 잘린다.
    @ViewBuilder
    private func photoImageView(_ photo: URL) -> some View {
        if let image = UIImage(contentsOfFile: photo.path()) {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        }
    }
}
