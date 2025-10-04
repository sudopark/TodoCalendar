//
//  ConfirmButton.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/31/23.
//

import SwiftUI


public struct ConfirmButton: View {
    
    private let title: String
    private let textColor: Color?
    private let backgroundColor: Color?
    private var isEnable: Bool
    private var isProcessing: Bool
    
    @Environment(ViewAppearance.self) private var appearance
    public var onTap: () -> Void = { }
    
    public init(
        title: String, 
        isEnable: Bool = true,
        isProcessing: Bool = false,
        textColor: Color? = nil,
        backgroundColor: Color? = nil
    ) {
        self.title = title
        self.isEnable = isEnable
        self.isProcessing = isProcessing
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
    
    private var colorForText: Color {
        return self.textColor ?? self.appearance.colorSet.primaryBtnText.asColor
    }
    
    private var colorForBackground: Color {
        return self.backgroundColor ?? self.appearance.colorSet.primaryBtnBackground.asColor
    }
    
    private var isDisable: Bool {
        return !self.isEnable || self.isProcessing
    }
    
    public var body: some View {
        Button {
            self.appearance.impactIfNeed(.light)
            self.onTap()
        } label: {
            if self.isProcessing {
                LoadingCircleView(.white)
                    .frame(width: 32, height: 32)
                    .frame(maxWidth: .infinity)
            } else {
                Text(title)
                    .font(self.appearance.fontSet.bottomButton.asFont)
                    .foregroundStyle(self.colorForText)
                    .frame(maxWidth: .infinity)
            }
        }
        .disabled(self.isDisable)
        .padding()
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    self.colorForBackground
                        .opacity(self.isEnable ? 1.0 : 0.5)
                )
        )
    }
}
