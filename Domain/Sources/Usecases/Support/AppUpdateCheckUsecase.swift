//
//  AppUpdateCheckUsecase.swift
//  Domain
//

import Foundation
import Combine
import CombineExt
import AsyncFlatMap
import Extensions


// MARK: - AppUpdateCheckUsecase

public protocol AppUpdateCheckUsecase: Sendable {
    func checkUpdateIsNeed()
    var updateRequirement: AnyPublisher<AppUpdateRequirement, Never> { get }
    var isUpdateAvailable: AnyPublisher<Bool, Never> { get }
}


// MARK: - AppUpdateCheckUsecaseImple

public final class AppUpdateCheckUsecaseImple: AppUpdateCheckUsecase, @unchecked Sendable {

    private let appRepository: any AppRepository
    private let currentAppVersion: String?

    public init(
        appRepository: any AppRepository,
        deviceInfoFetchService: any DeviceInfoFetchService
    ) {
        self.appRepository = appRepository
        self.currentAppVersion = deviceInfoFetchService.fetchAppVersion()

        guard let appVersion = self.currentAppVersion
        else { return }
        self.bindCheckTrigger(appVersion)
    }

    private struct Subject {
        let checkTrigger = PassthroughSubject<Void, Never>()
        let appUpdateRequirement = PassthroughSubject<AppUpdateRequirement, Never>()
        let currentUpdateInfo = CurrentValueSubject<AppUpdateInfo?, Never>(nil)
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}


extension AppUpdateCheckUsecaseImple {

    public func checkUpdateIsNeed() {
        self.subject.checkTrigger.send(())
    }

    private func bindCheckTrigger(_ currentAppVersion: String) {

        self.subject.checkTrigger
            .mapAsAnyError()
            .flatMapLatest { [weak self] in
                return self?.loadUpdateInfoWithoutError() ?? Empty().eraseToAnyPublisher()
            }
            .handleEvents(receiveOutput: { [weak self] info in
                self?.subject.currentUpdateInfo.send(info)
            })
            .compactMap { [weak self] info in
                return self?.checkAppVersion(currentAppVersion, updateInfo: info)
            }
            .sink(receiveValue: { [weak self] requirement in
                self?.subject.appUpdateRequirement.send(requirement)
            })
            .store(in: &self.cancellables)
    }

    private func loadUpdateInfoWithoutError() -> AnyPublisher<AppUpdateInfo?, any Error> {
        let repository = self.appRepository
        return Publishers.create(do: {
            do {
                return try await repository.loadUpdateInfo()
            } catch {
                return nil
            }
        })
        .eraseToAnyPublisher()
    }

    private func checkAppVersion(_ current: String, updateInfo: AppUpdateInfo?) -> AppUpdateRequirement? {
        return updateInfo.flatMap { AppUpdateRequirement(current: current, appUpdateInfo: $0) }
    }
}

extension AppUpdateCheckUsecaseImple {

    public var updateRequirement: AnyPublisher<AppUpdateRequirement, Never> {
        return self.subject.appUpdateRequirement
            .eraseToAnyPublisher()
    }

    public var isUpdateAvailable: AnyPublisher<Bool, Never> {
        let currentAppVersion = self.currentAppVersion
        return self.subject.currentUpdateInfo
            .map { info -> Bool in
                guard let current = currentAppVersion,
                      let latest = info?.latestVersion
                else { return false }
                return current.isVersionLessThan(latest)
            }
            .eraseToAnyPublisher()
    }
}


extension AppUpdateRequirement {

    public init?(current: String, appUpdateInfo: AppUpdateInfo) {
        if let forceVersion = appUpdateInfo.forceUpdateVersion,
           current.isVersionLessThan(forceVersion) {
            self = .forceRequired
            return
        }
        if let recommendVersion = appUpdateInfo.recommendUpdateVersion,
           current.isVersionLessThan(recommendVersion) {
            self = .recommended
            return
        }
        return nil
    }
}


private extension String {

    func isVersionLessThan(_ target: String) -> Bool {
        let currentParts = self.split(separator: ".")
        let targetParts = target.split(separator: ".")
        let maxCount = max(currentParts.count, targetParts.count)
        let pad: ([Substring]) -> String = { parts in
            let filled = parts.map(String.init) + Array(repeating: "0", count: maxCount - parts.count)
            return filled.joined(separator: ".")
        }
        return pad(currentParts).compare(pad(targetParts), options: .numeric) == .orderedAscending
    }
}
