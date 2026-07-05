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
            .frame(maxWidth: .infinity)
            .frame(height: 56)
    }
}

private struct WaveformBars: View {

    let level: CGFloat
    let color: Color

    private let barWidth: CGFloat = 5
    private let minSpacing: CGFloat = 10
    private let horizontalMargin: CGFloat = 8
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 36

    var body: some View {
        GeometryReader { proxy in
            let count = self.barCount(for: proxy.size.width)
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 0) {
                    ForEach(Array(0..<count), id: \.self) { index in
                        Capsule()
                            .fill(self.color)
                            .frame(width: self.barWidth, height: self.barHeight(index, count, at: time))
                        if index < count - 1 {
                            Spacer(minLength: self.minSpacing)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, self.horizontalMargin)
        }
    }

    // 주어진 너비에서 좌우 여백을 뺀 뒤, 막대+최소간격 단위로 최대 몇 개가 들어가는지 계산.
    private func barCount(for width: CGFloat) -> Int {
        let available = width - self.horizontalMargin * 2
        guard available > self.barWidth else { return 1 }
        let count = Int((available + self.minSpacing) / (self.barWidth + self.minSpacing))
        return max(1, count)
    }

    // 막대 높이는 level이 강도로 깔리고(0.8), 위에 작은 출렁임(0.2)만 얹는다.
    // 가운데 막대일수록 크게 반응(bell). level 0이면 전부 minHeight로 평평.
    private func barHeight(_ index: Int, _ count: Int, at time: TimeInterval) -> CGFloat {
        let center = Double(count - 1) / 2
        let weight = center <= 0 ? 1.0 : 1.0 - abs(Double(index) - center) / (center + 1)
        let wiggle = (sin(time * 9 + Double(index) * 0.9) + 1) / 2
        let intensity = self.level * CGFloat(weight) * (0.8 + 0.2 * CGFloat(wiggle))
        return self.minHeight + (self.maxHeight - self.minHeight) * intensity
    }
}
