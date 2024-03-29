//
//  ApplicationRootBuilder.swift
//  TodoCalendarApp
//
//  Created by sudo.park on 2023/08/07.
//

import UIKit
import Domain
import Repository
import Extensions


final class ApplicationRootBuilder {
    
    func makeRootViewModel() -> ApplicationRootViewModelImple {
        
        let remote = Singleton.shared.remoteAPI
        let authRepository = AuthRepositoryImple(
            remoteAPI: remote,
            authStore: Singleton.shared.keyChainStorage,
            keyChainStorage: Singleton.shared.keyChainStorage,
            firebaseAuthService: Singleton.shared.firebaseAuthService
        )
        let oauth2ServiceUsecaseProvider = OAuth2ServiceUsecaseProviderImple {
            // TODO: 이부분 객체로 바꿔줄필요있음
//            return (UIApplication.shared.delegate as? AppDelegate)?.applicationRouter?.window.rootViewController
            UIApplication.shared.windows.first?.rootViewController?.topPresentedViewController()
        }
        let accountUsecase: any AuthUsecase & AccountUsecase = AccountUsecaseImple(
            oauth2ServiceProvider: oauth2ServiceUsecaseProvider,
            authRepository: authRepository,
            sharedStore: Singleton.shared.sharedDataStore
        )
        let prepareUsecase = ApplicationUsecaseImple(
            accountUsecase: accountUsecase,
            latestAppSettingRepository: AppSettingRepositoryImple(
                environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
            ),
            sharedDataStore: Singleton.shared.sharedDataStore,
            database: Singleton.shared.commonSqliteService
        )
        let rootViewModel = ApplicationRootViewModelImple(
            authUsecase: accountUsecase,
            accountUsecase: accountUsecase,
            prepareUsecase: prepareUsecase
        )
        remote.attach(listener: rootViewModel)
        let rootRouter = ApplicationRootRouter(
            authUsecase: accountUsecase,
            accountUsecase: accountUsecase
        )
        rootViewModel.router = rootRouter
        
        return rootViewModel
    }
}


private extension UIViewController {
    
    func topPresentedViewController() -> UIViewController {
        guard let presented = self.presentedViewController else {
            return self
        }
        return presented.topPresentedViewController()
    }
}
