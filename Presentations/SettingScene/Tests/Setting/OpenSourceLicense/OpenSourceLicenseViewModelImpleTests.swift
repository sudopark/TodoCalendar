//
//  OpenSourceLicenseViewModelImpleTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


final class OpenSourceLicenseViewModelImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = .init()
    private let spyRouter = SpyRouter()
    
    private func makeViewModel() -> OpenSourceLicenseViewModelImple {
        let viewModel = OpenSourceLicenseViewModelImple()
        viewModel.router = self.spyRouter
        return viewModel
    }
    
    private func waitLibraries() async throws -> [OpenSourceLibrary] {
        let expect = expectConfirm("번들에 실린 라이브러리 목록 제공")
        let viewModel = self.makeViewModel()
        let libraries = try await self.firstOutput(expect, for: viewModel.libraries) {
            viewModel.prepare()
        }
        return libraries ?? []
    }
    
    private func waitLicenses() async throws -> [OpenSourceLicenseText] {
        let expect = expectConfirm("번들에 실린 라이선스 전문 제공")
        let viewModel = self.makeViewModel()
        let licenses = try await self.firstOutput(expect, for: viewModel.licenses) {
            viewModel.prepare()
        }
        return licenses ?? []
    }
}

extension OpenSourceLicenseViewModelImpleTests {
    
    @Test("고지 대상 라이브러리 30개를 이름·저작권·라이선스명·소스링크와 함께 제공한다")
    func viewModel_provideLibraries() async throws {
        // given & when
        let libraries = try await self.waitLibraries()
        
        // then
        #expect(libraries.count == 30)
        #expect(libraries.allSatisfy { !$0.name.isEmpty })
        #expect(libraries.allSatisfy { $0.copyright.localizedCaseInsensitiveContains("copyright") })
        #expect(libraries.allSatisfy { !$0.license.isEmpty })
        #expect(libraries.allSatisfy { $0.sourceURL.hasPrefix("https://") })
    }
    
    @Test("라이선스 종류별 전문 6부를 제공한다")
    func viewModel_provideLicenseTexts() async throws {
        // given & when
        let licenses = try await self.waitLicenses()
        
        // then
        #expect(licenses.count == 6)
        #expect(licenses.map { $0.name } == [
            "MIT License",
            "Apache License 2.0",
            "Apache License 2.0 with Runtime Library Exception",
            "BSD 3-Clause License",
            "zlib License",
            "Do What The Fuck You Want To Public License (WTFPL)"
        ])
        #expect(licenses.allSatisfy { $0.text.count > 300 })
    }
    
    @Test("모든 라이브러리의 라이선스가 전문 목록에 존재한다")
    func viewModel_everyLibraryLicenseHasFullText() async throws {
        // given
        let libraries = try await self.waitLibraries()
        let licenses = try await self.waitLicenses()
        
        // when
        let providedNames = Set(licenses.map { $0.name })
        let referencedNames = Set(libraries.map { $0.license })
        
        // then
        #expect(referencedNames.subtracting(providedNames).isEmpty)
        #expect(providedNames.subtracting(referencedNames).isEmpty)
    }
    
    @Test("라이브러리를 선택하면 소스 저장소를 사파리로 연다")
    func viewModel_whenSelectLibrary_openSourceRepository() async throws {
        // given
        let libraries = try await self.waitLibraries()
        let target = try #require(libraries.first(where: { $0.name == "Alamofire" }))
        let viewModel = self.makeViewModel()
        viewModel.prepare()
        
        // when
        viewModel.selectLibrary(target.name)
        
        // then
        #expect(self.spyRouter.didOpenSafariPath == target.sourceURL)
    }
    
    @Test("목록에 없는 라이브러리를 선택하면 아무것도 열지 않는다")
    func viewModel_whenSelectUnknownLibrary_doNothing() async throws {
        // given
        let viewModel = self.makeViewModel()
        viewModel.prepare()
        
        // when
        viewModel.selectLibrary("some unknown library")
        
        // then
        #expect(self.spyRouter.didOpenSafariPath == nil)
    }
    
    @Test("닫기를 선택하면 화면을 닫는다")
    func viewModel_close() async throws {
        // given
        let viewModel = self.makeViewModel()
        
        // when
        viewModel.close()
        
        // then
        #expect(self.spyRouter.didClosed == true)
    }
}


private final class SpyRouter: BaseSpyRouter, OpenSourceLicenseRouting, @unchecked Sendable { }
