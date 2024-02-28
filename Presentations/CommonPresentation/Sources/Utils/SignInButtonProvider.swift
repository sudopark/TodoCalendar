//
//  SignInButtonProvider.swift
//  CommonPresentation
//
//  Created by sudo.park on 2/22/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import GoogleSignInSwift

public protocol SignInButtonProvider {
    
    func button(
        _ provider: any OAuth2ServiceProvider,
        _ action: @escaping () -> Void
    ) -> any View
}

public struct SignInButtonProviderImple: SignInButtonProvider {
    
    public init() { }
    
    public func button(
        _ provider: any OAuth2ServiceProvider,
        _ action: @escaping () -> Void
    ) -> any View {
        switch provider {
        case let google as GoogleOAuth2ServiceProvider:
            // TODO: model 에서 테마변경 감지해야함
            let model = GoogleSignInButtonViewModel(style: .wide)
            return GoogleSignInButton(viewModel: model, action: action)
            
        default:
            return EmptyView()
        }
    }
}
