//
//  AppColdLaunchHistoryLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 8/24/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import Repository


struct AppColdLaunchHistoryLocalRepositoryImpleTests {

    private func makeRepository() -> AppColdLaunchHistoryLocalRepositoryImple {
        return AppColdLaunchHistoryLocalRepositoryImple(environmentStorage: FakeEnvironmentStorage())
    }
}

extension AppColdLaunchHistoryLocalRepositoryImpleTests {

    @Test("저장된 콜드 런치 이력이 없으면 기본값을 준다")
    func repository_whenNoStoredHistory_loadDefaultColdLaunchHistory() {
        // given
        let repository = self.makeRepository()

        // when
        let history = repository.loadColdLaunchHistory()

        // then
        #expect(history == AppColdLaunchHistory())
    }

    @Test("콜드 런치 이력을 저장하고 다시 읽는다")
    func repository_updateAndLoadColdLaunchHistory() {
        // given
        let repository = self.makeRepository()
        var history = AppColdLaunchHistory()
        history.recordLaunch(at: Date(timeIntervalSince1970: 100))
        history.recordLaunch(at: Date(timeIntervalSince1970: 100_000))

        // when
        repository.updateColdLaunchHistory(history)
        let loaded = repository.loadColdLaunchHistory()

        // then
        #expect(loaded == history)
    }
}
