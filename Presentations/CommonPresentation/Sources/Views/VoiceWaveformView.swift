//
//  VoiceWaveformView.swift
//  CommonPresentation
//
//  Created by sudo.park on 6/21/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI


// MARK: - VoiceWaveformView

public struct VoiceWaveformView: View {

    private let level: Float
    private let tintColor: Color

    public init(level: Float, tintColor: Color) {
        self.level = level
        self.tintColor = tintColor
    }

    public var body: some View {
        WaveformBars(level: CGFloat(self.level), color: self.tintColor)
            .frame(width: 144, height: 56)
    }
}

private struct WaveformBars: View {

    let level: CGFloat
    let color: Color

    private let barCount: Int = 7
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 56

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<self.barCount, id: \.self) { index in
                    Capsule()
                        .fill(self.color)
                        .frame(width: 5, height: self.barHeight(index, at: time))
                }
            }
        }
    }

    // 막대 높이는 level이 강도로 깔리고(0.8), 위에 작은 출렁임(0.2)만 얹는다.
    // 가운데 막대일수록 크게 반응(bell). level 0이면 전부 minHeight로 평평.
    private func barHeight(_ index: Int, at time: TimeInterval) -> CGFloat {
        let center = Double(self.barCount - 1) / 2
        let weight = 1.0 - abs(Double(index) - center) / (center + 1)
        let wiggle = (sin(time * 9 + Double(index) * 0.9) + 1) / 2
        let intensity = self.level * CGFloat(weight) * (0.8 + 0.2 * CGFloat(wiggle))
        return self.minHeight + (self.maxHeight - self.minHeight) * intensity
    }
}
