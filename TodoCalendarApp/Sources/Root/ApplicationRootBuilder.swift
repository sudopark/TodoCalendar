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
            keyChainStorage: Singleton.shared.keyChainStorage,
            firebaseAuthService: AppEnvironment.isTestBuild ? DummyFirebaseAuthService() : nil
        )
        let oauth2ServiceUsecaseProvider = OAuth2ServiceUsecaseProviderImple {
            // TODO: 이부분 객체로 바꿔줄필요있음
//            return (UIApplication.shared.delegate as? AppDelegate)?.applicationRouter?.window.rootViewController
            UIApplication.shared.windows.first?.rootViewController?.topPresentedViewController()
        }
        let authUsecase = AuthUsecaseImple(
            oauth2ServiceProvider: oauth2ServiceUsecaseProvider,
            authRepository: authRepository
        )
        let rootUsecase = ApplicationRootUsecaseImple(
            authRepository: authRepository,
            appSettingRepository: AppSettingRepositoryImple(
                environmentStorage: Singleton.shared.userDefaultEnvironmentStorage
            ),
            sharedDataStore: Singleton.shared.sharedDataStore
        )
        let rootViewModel = ApplicationRootViewModelImple(
            authUsecase: authUsecase,
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
}
