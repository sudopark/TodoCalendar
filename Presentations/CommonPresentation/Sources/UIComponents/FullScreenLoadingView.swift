//
//  FullScreenLoadingView.swift
//  CommonPresentation
//
//  Created by sudo.park on 2/23/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Extensions


public struct FullScreenLoadingView: View {
    
    @EnvironmentObject private var appearance: ViewAppearance
    private let message: String
    @Binding var isLoading: Bool
    
    public init(
        isLoading: Binding<Bool>,
        message: String? = nil
    ) {
        self._isLoading = isLoading
        self.message = R.String.commonWaitMessage
    }
    
    public var body: some View {
        if isLoading {
            VStack {
                self.messageLabel
                self.loadingView
            }
            .padding(20)
            .background(Color.black.opacity(0.8))
            .cornerRadius(16)
        } else {
            EmptyView()
        }
    }
    
    private var messageLabel: some View {
        Text(message)
            .foregroundColor(.white.opacity(0.8))
            .font(appearance.fontSet.normal.asFont)
    }
    
    private var loadingView: some View {
        LoadingCircleView(.white)
            .frame(width: 50, height: 50)
    }
}
