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
        
        let authRepository = AuthRepositoryImple(
            remoteAPI: Singleton.shared.remoteAPI,
            authStore: Singleton.shared.keyChainStorage,
            keyChainStorage: Singleton.shared.keyChainStorage,
            firebaseAuthService: AppEnvironment.isTestBuild ? DummyFirebaseAuthService() : nil
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
        let rootUsecase = ApplicationRootUsecaseImple(
            accountUsecase: accountUsecase,
            appSettingRepository: AppSettingRepositoryImple(
                environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
            ),
            sharedDataStore: Singleton.shared.sharedDataStore
        )
        let rootViewModel = ApplicationRootViewModelImple(
            authUsecase: accountUsecase,
            accountUsecase: accountUsecase,
            applicationUsecase: rootUsecase
        )
        let rootRouter = ApplicationRootRouter()
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


class DummyFirebaseAuthService: FirebaseAuthService {
    
    func authorize(with credential: any OAuth2Credential) async throws -> any FirebaseAuthDataResult {
        throw RuntimeError("failed")
    }
    
    func refreshToken(_ resultHandler: @escaping (Result<AuthRefreshResult, Error>) -> Void) {
        
    }
}
