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
        
        let applicationBase = ApplicationBase()
        
        let remote = applicationBase.remoteAPI
        let authRepository = AuthRepositoryImple(
            remoteAPI: remote,
            authStore: applicationBase.authStore,
            keyChainStorage: applicationBase.keyChainStorage,
            firebaseAuthService: applicationBase.firebaseAuthService
        )
        let oauth2ServiceUsecaseProvider = OAuth2ServiceUsecaseProviderImple {
            // TODO: 이부분 객체로 바꿔줄필요있음
//            return (UIApplication.shared.delegate as? AppDelegate)?.applicationRouter?.window.rootViewController
            UIApplication.shared.windows.first?.rootViewController?.topPresentedViewController()
        }
        let accountUsecase: any AuthUsecase & AccountUsecase = AccountUsecaseImple(
            oauth2ServiceProvider: oauth2ServiceUsecaseProvider,
            authRepository: authRepository,
            sharedStore: applicationBase.sharedDataStore
        )
        let prepareUsecase = ApplicationPrepareUsecaseImple(
            accountUsecase: accountUsecase,
            latestAppSettingRepository: AppSettingLocalRepositoryImple(
                storage: .init(environmentStorage: applicationBase.userDefaultEnvironmentStorage)
            ),
            sharedDataStore: applicationBase.sharedDataStore,
            database: applicationBase.commonSqliteService
        )
        let rootViewModel = ApplicationRootViewModelImple(
            authUsecase: accountUsecase,
            accountUsecase: accountUsecase,
            prepareUsecase: prepareUsecase,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        remote.attach(listener: rootViewModel)
        let rootRouter = ApplicationRootRouter(
            authUsecase: accountUsecase,
            accountUsecase: accountUsecase,
            applicationBase: applicationBase
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
