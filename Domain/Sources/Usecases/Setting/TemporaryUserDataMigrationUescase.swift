//
//  TemporaryUserDataMigrationUescase.swift
//  Domain
//
//  Created by sudo.park on 4/13/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Extensions


// MARK: - TemporaryUserDataMigrationUescase

public protocol TemporaryUserDataMigrationUescase: Sendable, AnyObject {
    
    func checkIsNeedMigration()
    func startMigration()
    
    var isNeedMigration: AnyPublisher<Bool, Never> { get }
    var migrationNeedEventCount: AnyPublisher<Int, Never> { get }
    var isMigrating: AnyPublisher<Bool, Never> { get }
    var migrationResult: AnyPublisher<Result<Void, any Error>, Never> { get }
}


// MARK: - TemporaryUserDataMigrationUescaseImple

public final class TemporaryUserDataMigrationUescaseImple: TemporaryUserDataMigrationUescase, @unchecked Sendable {
    
    private let migrationRepository: TemporaryUserDataMigrationRepository
    
    public init(
        migrationRepository: TemporaryUserDataMigrationRepository
    ) {
        self.migrationRepository = migrationRepository
    }
    
    private struct Subject {
        let isMigrating = CurrentValueSubject<Bool, Never>(false)
        let migrationNeedEventsCount = CurrentValueSubject<Int, Never>(0)
        let migrationResult = PassthroughSubject<Result<Void, any Error>, Never>()
    }
    private let subject = Subject()
    private var cancellables: Set<AnyCancellable> = []
}


extension TemporaryUserDataMigrationUescaseImple {
    
    public func checkIsNeedMigration() {
        
        Task { [weak self] in
            do {
                try await self?.updateMigrationNeedCount()
            } catch {
                logger.log(level: .error, "migration check fail: \(error)")
            }
        }
        .store(in: &self.cancellables)
    }
    
    public func startMigration() {
        Task { [weak self] in
            self?.subject.isMigrating.send(true)
            do {
                try await self?.migrationRepository.migrateEventTags()
                try await self?.migrationRepository.migrateTodoEvents()
                try await self?.migrationRepository.migrateScheduleEvents()
                try? await self?.migrationRepository.migrateEventDetails()
                try? await self?.migrationRepository.migrateDoneEvents()
                try? await self?.migrationRepository.clearTemporaryUserData()
                self?.subject.isMigrating.send(false)
                self?.subject.migrationResult.send(.success(()))
            } catch {
                self?.subject.isMigrating.send(false)
                self?.subject.migrationResult.send(.failure(error))
            }
            
            try await self?.updateMigrationNeedCount()
        }
        .store(in: &self.cancellables)
    }
    
    private func updateMigrationNeedCount() async throws {
        let count = try await self.migrationRepository.loadMigrationNeedEventCount()
        self.subject.migrationNeedEventsCount.send(count)
    }
}


extension TemporaryUserDataMigrationUescaseImple {
    
    public var isNeedMigration: AnyPublisher<Bool, Never> {
        return self.subject.migrationNeedEventsCount
            .map { $0 > 0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    public var migrationNeedEventCount: AnyPublisher<Int, Never> {
        return self.subject.migrationNeedEventsCount
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    public var isMigrating: AnyPublisher<Bool, Never> {
        return self.subject.isMigrating
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public var migrationResult: AnyPublisher<Result<Void, any Error>, Never> {
        return self.subject.migrationResult
            .eraseToAnyPublisher()
    }
}


// MARK: - NotNeedTemporaryUserDataMigrationUescaseImple

public final class NotNeedTemporaryUserDataMigrationUescaseImple: TemporaryUserDataMigrationUescase {
    
    public init() { }
    
    public func checkIsNeedMigration() { }
    
    public func startMigration() { }
    
    public var isNeedMigration: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
    public var migrationNeedEventCount: AnyPublisher<Int, Never> { Just(0).eraseToAnyPublisher() }
    public var isMigrating: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
    public var migrationResult: AnyPublisher<Result<Void, any Error>, Never> { Empty().eraseToAnyPublisher() }
}
