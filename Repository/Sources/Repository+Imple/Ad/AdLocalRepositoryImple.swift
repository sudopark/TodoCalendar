//
//  AdLocalRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


public final class AdLocalRepositoryImple: AdRepository, Sendable {

    private let environmentStorage: any EnvironmentStorage

    public init(environmentStorage: any EnvironmentStorage) {
        self.environmentStorage = environmentStorage
    }

    private var exposureRecordsKey: String { EnvironmentKeys.fullScreenAdExposureRecords.rawValue }
}

extension AdLocalRepositoryImple {

    public func loadFullScreenAdExposureRecords() -> [FullScreenAdExposureRecord] {
        let mappers: [FullScreenAdExposureRecordMapper]? = self.environmentStorage.load(
            self.exposureRecordsKey
        )
        return mappers?.map { $0.record } ?? []
    }

    public func updateFullScreenAdExposureRecord(_ record: FullScreenAdExposureRecord) {
        let others = self.loadFullScreenAdExposureRecords().filter { $0.scope != record.scope }
        let mappers = (others + [record]).map { FullScreenAdExposureRecordMapper(record: $0) }
        self.environmentStorage.update(self.exposureRecordsKey, mappers)
    }
}
