//
//  LoadingCircleView.swift
//  CommonPresentation
//
//  Created by sudo.park on 11/18/23.
//

import SwiftUI


public struct LoadingCircleView: View {
    
    @State private var percent: CGFloat = 0
    private let layerColor: Color
    
    public init(_ layerColor: Color) {
        self.layerColor = layerColor
    }
    
    public var body: some View {
        
        ProgessLine()
            .trim(from: 0, to: self.percent)
            .stroke(
                self.layerColor,
                style: .init(lineWidth: 3.5, lineCap: .round)
            )
            .animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true), value: self.percent)
            .aspectRatio(1, contentMode: .fit)
            .rotationEffect(Angle(degrees: 360 * self.percent))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: self.percent)
            .onAppear {
                self.percent = 1.0
            }
    }
}

struct ProgessLine: Shape {

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.size.width/2, y: rect.size.height/2)
        let radius = rect.size.height * 0.35
        path.addArc(
            center: center,
            radius: radius,
            startAngle: Angle(degrees: 360 * 0.1),
            endAngle: Angle(degrees: 360 * 1.2),
            clockwise: true
        )
        return path
    }
}
