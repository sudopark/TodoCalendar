//
//  ManageAccountViewModelImpleTests.swift
//  MemberScenesTests
//
//  Created by sudo.park on 4/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Domain
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import MemberScenes


class ManageAccountViewModelImpleTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
    }
    
    private func makeViewModel(
        shouldFailMigration: Bool = false
    ) -> ManageAccountViewModelImple {
        
        let authUsecase = StubAuthUsecase()
        let accountUsecase = StubAccountUsecase(.init("id"))
        let migrationUsecase = StubTemporaryUserDataMigrationUescase()
        migrationUsecase.shouldFail = shouldFailMigration
        let viewModel = ManageAccountViewModelImple(
            authUsecase: authUsecase,
            accountUsecase: accountUsecase,
            migrationUsecase: migrationUsecase
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension ManageAccountViewModelImpleTests {
        
    func testViewModel_provideCurrentAccountInfo() {
        // given
        let expect = expectation(description: "provide current account info")
        let viewModel = self.makeViewModel()
        
        // when
        let info = self.waitFirstOutput(expect, for: viewModel.currentAccountInfo) {
            viewModel.prepare()
        }
        
        // then
        XCTAssertNotNil(info)
    }
    
    // update migration need count after migration
    func testViewModel_updateMigrationNeedCountAfterMigrationSuccess() {
        // given
        let expect = expectation(description: "마이그레이션 완료(성공) 이후 필요 카운트 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let counts = self.waitOutputs(expect, for: viewModel.isNeedMigrationEventCount) {
            viewModel.prepare()
            viewModel.handleMigration()
        }
        
        // then
        XCTAssertEqual(counts, [0, 100, 0])
        XCTAssertEqual(self.spyRouter.didShowToastWithMessage != nil, true)
    }
    
    func testViewModel_updateMigrationNeedCountAfterMigrationFailed() {
        // given
        let expect = expectation(description: "마이그레이션 완료(실패) 이후 필요 카운트 업데이트")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel(shouldFailMigration: true)
        
        // when
        let counts = self.waitOutputs(expect, for: viewModel.isNeedMigrationEventCount) {
            viewModel.prepare()
            viewModel.handleMigration()
        }
        
        // then
        XCTAssertEqual(counts, [0, 100, 10])
        XCTAssertEqual(self.spyRouter.didShowError != nil, true)
    }
    
    func testViewModel_whenMigration_updateIsMigrating() {
        // given
        func parameterizeTest(shouldSuccess: Bool) {
            // given
            let expect = expectation(description: "마이그레이션도중에는 마이그레이션 플래그 업데이트")
            expect.expectedFulfillmentCount = 3
            let viewModel = self.makeViewModel(shouldFailMigration: !shouldSuccess)
            
            // when
            let flags = self.waitOutputs(expect, for: viewModel.isMigrating) {
                viewModel.prepare()
                viewModel.handleMigration()
            }
            
            // then
            XCTAssertEqual(flags, [false, true, false])
        }
        // when + then
        parameterizeTest(shouldSuccess: true)
        parameterizeTest(shouldSuccess: false)
    }
    
    // signout with confirm
    func testViewModel_signOutWithConfirm() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.signOut()
        
        // then
        XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
    }
    
    func testViewModel_whenSignOut_updateIsSignOut() {
        // given
        let expect = expectation(description: "로그아웃중에는 로그아웃중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let flags = self.waitOutputs(expect, for: viewModel.isSigningOut) {
            viewModel.signOut()
        }
        
        // then
        XCTAssertEqual(flags, [false, true, false])
    }
    
    func testViewModel_deleteAccountWithConfirm() {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.deleteAccount()
        
        // then
        XCTAssertEqual(self.spyRouter.didShowConfirmWith != nil, true)
    }
    
    func testViewModel_whenDeleteAccount_updateIsSignOut() {
        // given
        let expect = expectation(description: "회원탈퇴 중에는 탈퇴중임을 알림")
        expect.expectedFulfillmentCount = 3
        let viewModel = self.makeViewModel()
        
        // when
        let flags = self.waitOutputs(expect, for: viewModel.isDeletingAccount) {
            viewModel.deleteAccount()
        }
        
        // then
        XCTAssertEqual(flags, [false, true, false])
    }
}

private class SpyRouter: BaseSpyRouter, ManageAccountRouting, @unchecked Sendable { }
