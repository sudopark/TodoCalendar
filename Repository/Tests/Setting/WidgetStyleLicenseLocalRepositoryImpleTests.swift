//
//  WidgetStyleLicenseLocalRepositoryImpleTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 10/8/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import Foundation
import Domain

@testable import Repository


struct WidgetStyleLicenseLocalRepositoryImpleTests {

    private func makeRepository(
        storage: FakeEnvironmentStorage = FakeEnvironmentStorage()
    ) -> WidgetStyleLicenseLocalRepositoryImple {
        return WidgetStyleLicenseLocalRepositoryImple(environmentStorage: storage)
    }
}


extension WidgetStyleLicenseLocalRepositoryImpleTests {

    @Test("저장된 사용권 기록이 없으면 nil 을 준다")
    func repository_loadLicense_whenEmpty_isNil() {
        // given
        let repository = self.makeRepository()

        // when
        let license = repository.loadLicense()

        // then
        #expect(license == nil)
    }

    @Test("사용권 기록을 저장하고 다시 읽는다")
    func repository_updateAndLoadLicense() {
        // given
        let repository = self.makeRepository()
        let license = WidgetStyleLicense(grantedAt: Date(timeIntervalSince1970: 100))

        // when
        repository.updateLicense(license)
        let loaded = repository.loadLicense()

        // then
        #expect(loaded == license)
    }

    @Test("사용권을 다시 기록하면 누적하지 않고 교체한다")
    func repository_updateLicenseTwice_replacesRecord() {
        // given
        let repository = self.makeRepository()
        repository.updateLicense(.init(grantedAt: Date(timeIntervalSince1970: 100)))
        let latest = WidgetStyleLicense(grantedAt: Date(timeIntervalSince1970: 200))

        // when
        repository.updateLicense(latest)
        let loaded = repository.loadLicense()

        // then
        #expect(loaded == latest)
    }

    @Test("같은 storage 를 쓰는 컬러 테마 사용권과 서로 덮어쓰지 않는다")
    func repository_widgetAndColorThemeLicense_doNotOverwriteEachOther() {
        // given
        let storage = FakeEnvironmentStorage()
        let widgetRepository = self.makeRepository(storage: storage)
        let colorThemeRepository = ColorThemeLicenseLocalRepositoryImple(environmentStorage: storage)
        let widgetLicense = WidgetStyleLicense(grantedAt: Date(timeIntervalSince1970: 100))
        let colorThemeLicense = ColorThemeLicense(grantedAt: Date(timeIntervalSince1970: 200))

        // when
        widgetRepository.updateLicense(widgetLicense)
        colorThemeRepository.updateLicense(colorThemeLicense)

        // then
        #expect(widgetRepository.loadLicense() == widgetLicense)
        #expect(colorThemeRepository.loadLicense() == colorThemeLicense)
    }

    @Test("같은 storage 를 쓰는 앱 정책 캐시와 서로 덮어쓰지 않는다")
    func repository_licenseAndAppPolicy_doNotOverwriteEachOther() async throws {
        // given
        let storage = FakeEnvironmentStorage()
        let licenseRepository = self.makeRepository(storage: storage)
        let remote = StubRemoteAPI(responses: [
            .init(
                method: .get,
                endpoint: AppEndpoints.appPolicy,
                resultJsonString: .success(#"{"widget_style_license": {"enabled": true, "license_days": 14}}"#)
            )
        ])
        let policyRepository = AppPolicyRepositoryImple(
            remoteAPI: remote, environmentStorage: storage
        )
        let license = WidgetStyleLicense(grantedAt: Date(timeIntervalSince1970: 100))

        // when
        licenseRepository.updateLicense(license)
        try await policyRepository.refreshPolicy()

        // then
        #expect(licenseRepository.loadLicense() == license)
        #expect(policyRepository.loadPolicy()?.widgetStyleLicense == .init(isEnabled: true, licenseDays: 14))
    }
}
