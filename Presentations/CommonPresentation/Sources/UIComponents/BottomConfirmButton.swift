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
    
    public var body: some View {
        
        ZStack {
            ConfirmButton(
                title: self.title,
                isEnable: self.isEnable,
                isProcessing: self.isProcessing
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
