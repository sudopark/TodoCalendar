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
    @Binding private var isEnable: Bool
    
    @EnvironmentObject private var appearance: ViewAppearance
    public var onTap: () -> Void = { }
    
    public init(
        title: String, 
        isEnable: Binding<Bool> = .constant(true),
        textColor: Color? = nil,
        backgroundColor: Color? = nil
    ) {
        self.title = title
        self._isEnable = isEnable
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
    
    private var colorForText: Color {
        return self.textColor ?? self.appearance.colorSet.primaryBtnText.asColor
    }
    
    private var colorForBackground: Color {
        return self.backgroundColor ?? self.appearance.colorSet.primaryBtnBackground.asColor
    }
    
    public var body: some View {
        Button {
            self.onTap()
        } label: {
            Text(title)
                .font(self.appearance.fontSet.bottomButton.asFont)
                .foregroundStyle(self.colorForText)
        }
        .disabled(!self.isEnable)
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    self.colorForBackground
                        .opacity(self.isEnable ? 1.0 : 0.5)
                )
        )
    }
}
