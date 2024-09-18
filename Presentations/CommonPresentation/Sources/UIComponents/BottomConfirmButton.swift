//
//  BottomConfirmButton.swift
//  CommonPresentation
//
//  Created by sudo.park on 10/31/23.
//

import SwiftUI


public struct BottomConfirmButton: View {
    
    private let title: String
    private let textColor: Color?
    private let backgroundColor: Color?
    @Binding private var isEnable: Bool
    @Binding private var isProcessing: Bool
    
    @EnvironmentObject private var appearance: ViewAppearance
    public var onTap: () -> Void = { }
    
    public init(
        title: String,
        isEnable: Binding<Bool> = .constant(true),
        isProcessing: Binding<Bool> = .constant(false),
        textColor: Color? = nil,
        backgroundColor: Color? = nil
    ) {
        self.title = title
        self._isEnable = isEnable
        self._isProcessing = isProcessing
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
    
    public var body: some View {
        
        ZStack {
            ConfirmButton(
                title: self.title,
                isEnable: self._isEnable,
                isProcessing: self._isProcessing
            )
            .eventHandler(\.onTap, {
                self.appearance.impactIfNeed(.light)
                self.onTap()
            })
        }
        .padding()
        .background(
            Rectangle()
                .fill(self.appearance.colorSet.dayBackground.asColor)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
