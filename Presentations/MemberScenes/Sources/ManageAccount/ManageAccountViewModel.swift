//
//  
//  ManageAccountViewModel.swift
//  MemberScenes
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


struct AccountInfoModel: Equatable {
    var emailAddress: String?
    var signInMethod: String?
    var lastSignedIn: String?
}

// MARK: - ManageAccountViewModel

protocol ManageAccountViewModel: AnyObject, Sendable, ManageAccountSceneInteractor {

    // interactor
    func close()
    func prepare()
    func handleMigration()
    func showPrivatePolicy()
    func signOut()
    
    // presenter
    var currentAccountInfo: AnyPublisher<AccountInfoModel, Never> { get }
    var isNeedMigrationEventCount: AnyPublisher<Int, Never> { get }
    var isMigrating: AnyPublisher<Bool, Never> { get }
    var isSigningOut: AnyPublisher<Bool, Never> { get }
}


// MARK: - ManageAccountViewModelImple

final class ManageAccountViewModelImple: ManageAccountViewModel, @unchecked Sendable {
    
    private enum Constant {
        static let privatePolicyURLPath = ""
    }
    
    private let authUsecase: any AuthUsecase
    private let accountUsecase: any AccountUsecase
    private let migrationUsecase: any TemporaryUserDataMigrationUescase
    var router: (any ManageAccountRouting)?
    
    init(
        authUsecase: any AuthUsecase,
        accountUsecase: any AccountUsecase,
        migrationUsecase: any TemporaryUserDataMigrationUescase
    ) {
        self.authUsecase = authUsecase
        self.accountUsecase = accountUsecase
        self.migrationUsecase = migrationUsecase
        
        self.internalBinding()
    }
    
    
    private struct Subject {
        let accountInfo = CurrentValueSubject<AccountInfo?, Never>(nil)
        let migrationNeedEventCount = CurrentValueSubject<Int, Never>(0)
        let isMigrating = CurrentValueSubject<Bool, Never>(false)
        let isSigningOut = CurrentValueSubject<Bool, Never>(false)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    
    private func internalBinding() {
        
        self.accountUsecase.currentAccountInfo
            .sink(receiveValue: { [weak self] info in
                self?.subject.accountInfo.send(info)
            })
            .store(in: &self.cancellables)
        
        self.migrationUsecase.migrationNeedEventCount
            .sink(receiveValue: { [weak self] count in
                self?.subject.migrationNeedEventCount.send(count)
            })
            .store(in: &self.cancellables)
        
        self.migrationUsecase.isMigrating
            .sink(receiveValue: { [weak self] flag in
                self?.subject.isMigrating.send(flag)
            })
            .store(in: &self.cancellables)
        
        self.migrationUsecase.migrationResult
            .sink(receiveValue: { [weak self] result in
                switch result {
                case .success:
                    self?.router?.showToast("manage_account::migration_finished::message")
                case .failure(let error):
                    self?.router?.showError(error)
                }
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - ManageAccountViewModelImple Interactor

extension ManageAccountViewModelImple {
    
    func close() {
        self.router?.closeScene()
    }
    
    func prepare() {
        self.migrationUsecase.checkIsNeedMigration()
    }
    
    func handleMigration() {
        guard self.subject.migrationNeedEventCount.value > 0,
              !self.subject.isMigrating.value
        else { return }
        
        self.migrationUsecase.startMigration()
    }
    
    func showPrivatePolicy() {
        self.router?.openSafari(Constant.privatePolicyURLPath)
    }
    
    func signOut() {
        guard !self.subject.isSigningOut.value else { return }
        
        let confirmed: () -> Void = { [weak self] in
            self?.processSignOut()
        }
        
        let info = ConfirmDialogInfo()
            |> \.title .~ "manage_account::sign_out::confirm::title".localized()
            |> \.message .~ pure("manage_account::sign_out::confirm::message".localized())
            |> \.confirmed .~ pure(confirmed)
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }
    
    private func processSignOut() {
        Task { [weak self] in
            self?.subject.isSigningOut.send(true)
            do {
                try await self?.authUsecase.signOut()
                self?.subject.isSigningOut.send(false)
            } catch {
                self?.subject.isSigningOut.send(false)
                self?.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
}


// MARK: - ManageAccountViewModelImple Presenter

extension ManageAccountViewModelImple {
 
    var currentAccountInfo: AnyPublisher<AccountInfoModel, Never> {
        let transform: (AccountInfo) -> AccountInfoModel = { info in
            return AccountInfoModel(
                emailAddress: info.email,
                signInMethod: info.signInMethod,
                lastSignedIn: info.lastSignIn.map {
                    Date(timeIntervalSince1970: $0).formatted(date: .numeric, time: .complete)
                }
            )
        }
        return self.subject.accountInfo
            .compactMap { $0 }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isNeedMigrationEventCount: AnyPublisher<Int, Never> {
        return self.subject.migrationNeedEventCount
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isMigrating: AnyPublisher<Bool, Never> {
        return self.subject.isMigrating
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isSigningOut: AnyPublisher<Bool, Never> {
        return self.subject.isSigningOut
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
