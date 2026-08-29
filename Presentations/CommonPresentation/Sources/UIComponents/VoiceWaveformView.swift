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
            .frame(height: 40)
    }
}

private struct WaveformBars: View {

    let level: CGFloat
    let color: Color

    private let barWidth: CGFloat = 3
    private let minSpacing: CGFloat = 5
    private let horizontalMargin: CGFloat = 32
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 26

    @State private var fromLevel: CGFloat = 0
    @State private var toLevel: CGFloat = 0
    @State private var transitionStart: TimeInterval = 0
    private let transitionDuration: TimeInterval = 0.4

    var body: some View {
        GeometryReader { proxy in
            let count = self.barCount(for: proxy.size.width)
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let level = self.smoothedLevel(at: time)
                HStack(spacing: 0) {
                    ForEach(Array(0..<count), id: \.self) { index in
                        Capsule()
                            .fill(self.color)
                            .frame(width: self.barWidth, height: self.barHeight(index, count, level: level, at: time))
                        if index < count - 1 {
                            Spacer(minLength: self.minSpacing)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, self.horizontalMargin)
        }
        .onAppear {
            self.fromLevel = self.level
            self.toLevel = self.level
        }
        .onChange(of: self.level) { _, newValue in
            let now = Date().timeIntervalSinceReferenceDate
            self.fromLevel = self.smoothedLevel(at: now)
            self.toLevel = newValue
            self.transitionStart = now
        }
    }

    private func barCount(for width: CGFloat) -> Int {
        let available = width - self.horizontalMargin * 2
        guard available > self.barWidth else { return 1 }
        let count = Int((available + self.minSpacing) / (self.barWidth + self.minSpacing))
        return max(1, count)
    }

    private func smoothedLevel(at time: TimeInterval) -> CGFloat {
        let elapsed = time - self.transitionStart
        guard elapsed < self.transitionDuration else { return self.toLevel }
        let t = max(0, elapsed / self.transitionDuration)
        let eased = t * t * (3 - 2 * t)
        return self.fromLevel + (self.toLevel - self.fromLevel) * CGFloat(eased)
    }

    private func barHeight(_ index: Int, _ count: Int, level: CGFloat, at time: TimeInterval) -> CGFloat {
        let i = Double(index)
        let phase = i * 0.7

        // 서로 다른 주파수의 사인을 겹쳐 단조로움을 깬다.
        let wave = sin(time * 9 + phase) * 0.6
                 + sin(time * 15 + phase * 1.9) * 0.4
        // 부호를 유지한 채 pow로 피크를 뾰족하게 → 통통 튀는 탄력감.
        let shaped = wave >= 0 ? pow(wave, 0.6) : -pow(-wave, 0.6)
        let wiggle = (shaped + 1) / 2

        // 막대마다 고정 진폭 편차를 줘서 높이가 균일하지 않게.
        let variance = 0.7 + 0.3 * sin(i * 2.3)

        let center = Double(count - 1) / 2
        let weight = center <= 0 ? 1.0 : 1.0 - abs(i - center) / (center + 1) * 0.5

        let intensity = level * CGFloat(weight) * CGFloat(variance) * (0.3 + 0.7 * CGFloat(wiggle))
        return self.minHeight + (self.maxHeight - self.minHeight) * intensity
    }
}
