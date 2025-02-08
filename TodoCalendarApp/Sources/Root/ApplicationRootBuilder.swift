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
    
    @MainActor
    func makeRootViewModel() -> ApplicationRootViewModelImple {
        
        let applicationBase = ApplicationBase()
        let topViewControllerFinding: () -> UIViewController? = {
            // TODO: 이부분 객체로 바꿔줄필요있음
//            return (UIApplication.shared.delegate as? AppDelegate)?.applicationRouter?.window.rootViewController
            UIApplication.shared.windows.first?.rootViewController?.topPresentedViewController()
        }
        let remote = applicationBase.remoteAPI
        let accountUsecase = self.makeAccountUsecase(
            applicationBase, remote, topViewControllerFinding
        )
        
        let externalServiceRemotes = [
            AppEnvironment.googleCalendarService.identifier: applicationBase.googleCalendarRemoteAPI
        ]
        let externalCalendarIntegrationUsecase = self.makeExternalCalendarIntegrationUsecase(
            applicationBase, externalServiceRemotes, topViewControllerFinding
        )
        
        let prepareUsecase = ApplicationPrepareUsecaseImple(
            accountUsecase: accountUsecase,
            externalCalenarIntegrationUsecase: externalCalendarIntegrationUsecase,
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
            externalCalendarServiceUsecase: externalCalendarIntegrationUsecase,
            environmentStorage: applicationBase.userDefaultEnvironmentStorage
        )
        remote.attach(listener: rootViewModel)
        externalServiceRemotes.values.forEach {
            $0.attach(listener: rootViewModel)
        }
        let rootRouter = ApplicationRootRouter(
            authUsecase: accountUsecase,
            accountUsecase: accountUsecase,
            externalCalenarIntegrationUsecase: externalCalendarIntegrationUsecase,
            applicationBase: applicationBase
        )
        rootViewModel.router = rootRouter
        
        return rootViewModel
    }
    
    private func makeAccountUsecase(
        _ applicationBase: ApplicationBase,
        _ remote: some RemoteAPI,
        _ topViewControllerFinding: @escaping () -> UIViewController?
    ) -> some AccountUsecase & AuthUsecase {
        let remote = applicationBase.remoteAPI
        let authRepository = AuthRepositoryImple(
            remoteAPI: remote,
            authStore: applicationBase.authStore,
            keyChainStorage: applicationBase.keyChainStorage,
            firebaseAuthService: applicationBase.firebaseAuthService
        )
        let oauth2ServiceUsecaseProvider = OAuth2ServiceUsecaseProviderImple(
            topViewControllerFinding: topViewControllerFinding
        )
        return AccountUsecaseImple(
            oauth2ServiceProvider: oauth2ServiceUsecaseProvider,
            authRepository: authRepository,
            sharedStore: applicationBase.sharedDataStore
        )
    }
    
    private func makeExternalCalendarIntegrationUsecase(
        _ applicationBase: ApplicationBase,
        _ remotes: [String: any RemoteAPI],
        _ topViewControllerFinding: @escaping () -> UIViewController?
    ) -> some ExternalCalendarIntegrationUsecase {
        let integrationRepository = ExternalCalendarIntegrateRepositoryImple(
            supportServices: AppEnvironment.supportExternalCalendarServices,
            removeAPIPerService: remotes,
            keyChainStore: applicationBase.keyChainStorage
        )
        let externalServiceOAuth2ServiceUsecaseProvider = ExternalCalendarOAuthUsecaseProviderImple(
            topViewControllerFinding: topViewControllerFinding
        )
        return ExternalCalendarIntegrationUsecaseImple(
            oauth2ServiceProvider: externalServiceOAuth2ServiceUsecaseProvider,
            externalServiceIntegrateRepository: integrationRepository,
            sharedDataStore: applicationBase.sharedDataStore
        )
    }
}


extension UIViewController {
    
    func topPresentedViewController() -> UIViewController {
        guard let presented = self.presentedViewController else {
            return self
        }
        return presented.topPresentedViewController()
    }
}
