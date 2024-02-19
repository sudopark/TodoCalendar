//
//  
//  SignInViewModel.swift
//  MemberScenes
//
//  Created by sudo.park on 2/20/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Domain
import Scenes


// MARK: - SignInViewModel

protocol SignInViewModel: AnyObject, Sendable, SignInSceneInteractor {

    // interactor
    func signIn(_ provider: any OAuth2ServiceProvider)
    func close()
    
    // presenter
    var isSigningIn: AnyPublisher<Bool, Never> { get }
    var supportSignInOAuthService: [any OAuth2ServiceProvider] { get }
}


// MARK: - SignInViewModelImple

final class SignInViewModelImple: SignInViewModel, @unchecked Sendable {
    
    private let authUsecase: any AuthUsecase
    var router: (any SignInRouting)?
    
    init(
        authUsecase: any AuthUsecase
    ) {
        self.authUsecase = authUsecase
    }
    
    
    private struct Subject {
        let isSigningIn = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - SignInViewModelImple Interactor

extension SignInViewModelImple {
 
    func signIn(_ provider: OAuth2ServiceProvider) {
        Task { [weak self] in
            self?.subject.isSigningIn.send(true)
            do {
                let _ = try await self?.authUsecase.signIn(provider)
                self?.subject.isSigningIn.send(false)
                self?.router?.closeScene(animate: true, nil)
            } catch {
                self?.subject.isSigningIn.send(false)
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    func close() {
        guard self.subject.isSigningIn.value == false else { return }
        self.router?.closeScene(animate: true, nil)
    }
}


// MARK: - SignInViewModelImple Presenter

extension SignInViewModelImple {
    
    var isSigningIn: AnyPublisher<Bool, Never> {
        return self.subject.isSigningIn
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var supportSignInOAuthService: [OAuth2ServiceProvider] {
        return self.authUsecase.supportOAuth2Service
    }
}
