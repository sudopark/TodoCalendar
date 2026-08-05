//
//  ShareUsecaseFactory.swift
//  TodoCalendarAppShare
//
//  Created by sudo.park on 8/5/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Repository


struct ShareUsecaseFactory {

    private let base: AppExtensionBase
    init(base: AppExtensionBase) {
        self.base = base
    }
}

extension ShareUsecaseFactory {

    // job 생성 + 처리중 기록 두 가지만 필요하므로 usecase가 아닌 repository를 직접 만든다.
    // AICommandUsecaseImple.processCommand는 종료까지 폴링해서 확장 수명에 얹을 수 없다.
    func makeAICommandRepository() -> any AICommandRepository {
        // AI 엔드포인트는 인증 필수(CalendarAPIAutenticator.shouldAdapt).
        // 확장 프로세스의 remoteAPI에 저장된 auth를 seed하지 않으면 무인증으로 나간다 —
        // WidgetUsecaseFactory·IntentReposiotryFactory와 같은 처리.
        if let auth = self.base.authStore.loadCurrentAuth() {
            self.base.remoteAPI.setup(credential: APICredential(auth: auth))
        }
        let localStorage = AICommandLocalStorageImple(
            sqliteService: self.base.writableSqliteService
        )
        return AICommandRepositoryImple(
            remote: self.base.remoteAPI,
            localStorage: localStorage
        )
    }

    func makeSubmitService() -> ShareCommandSubmitService {
        return ShareCommandSubmitService(
            repository: self.makeAICommandRepository(),
            authStore: self.base.authStore
        )
    }
}
