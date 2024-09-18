//
//  SignInButtonProvider.swift
//  CommonPresentation
//
//  Created by sudo.park on 2/22/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit


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
        case is GoogleOAuth2ServiceProvider:
            // TODO: model 에서 테마변경 감지해야함
            let model = GoogleSignInButtonViewModel(style: .wide)
            return GoogleSignInButton(viewModel: model, action: action)
            
        case let apple as AppleOAuth2ServiceProvider:
            return self.makeAppleSignInButton(apple, action)
            
        default:
            return EmptyView()
        }
    }
    
    private func makeAppleSignInButton(
        _ apple: AppleOAuth2ServiceProvider,
        _ actionCallback: @escaping () -> Void
    ) -> some View {
        
        let nonce = self.makeNonce()
        
        let handleSuccessResult: (ASAuthorization) -> Void = { authorization in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential
            else {
                apple.appleSignInResult = .failure(
                    RuntimeError("no ASAuthorizationAppleIDCredential")
                )
                return
            }
            
            guard let appleIDToken = credential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                apple.appleSignInResult = .failure(
                    RuntimeError("unavail to serialize IdToken")
                )
                return
            }
            apple.appleSignInResult = .success(
                .init(
                    appleIDToken: idTokenString,
                    nonce: nonce
                )
            )
        }
        
        return SignInWithAppleButton(
            onRequest: { request in
                request.requestedScopes = [.email]
                request.nonce = nonce
                    .data(using: .utf8)
                    .map { SHA256.hash(data: $0) }
                    .map { $0.map { String(format: "%02x", $0) }.joined() }
            },
            onCompletion: { result in
                switch result {
                case .success(let authorize):
                    handleSuccessResult(authorize)
                    actionCallback()
                    
                case .failure(let error):
                    apple.appleSignInResult = .failure(error)
                    actionCallback()
                }
            }
        )
        .signInWithAppleButtonStyle(.whiteOutline)
        .frame(height: 40)
    }
    
    private func makeNonce() -> String {
        let charset: [Character] =
              Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let makeRandIndexes: () -> Int = {
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
              fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }
            return Int(random) % charset.count
        }
        
        let randIndexes = (0..<16).map { _ in }.map(makeRandIndexes)
        return randIndexes.map { charset[$0] }.map { "\($0)" }.joined()
    }
}
