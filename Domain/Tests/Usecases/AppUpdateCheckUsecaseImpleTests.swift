//
//  AppUpdateCheckUsecaseImpleTests.swift
//  DomainTests
//

import XCTest
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


// MARK: - AppUpdateRequirement init 테스트 (버전 문자열 비교)

class AppUpdateRequirementTests: BaseTestCase {

    private func requirement(current: String, target: String) -> AppUpdateRequirement? {
        var info = AppUpdateInfo()
        info.forceUpdateVersion = target
        return AppUpdateRequirement(current: current, appUpdateInfo: info)
    }
}


// MARK: - major / minor / patch 단위 비교

extension AppUpdateRequirementTests {

    func test_whenMajorVersionIsLess_treatAsOutdated() {
        // given / when
        let result = self.requirement(current: "1.0.0", target: "2.0.0")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenMinorVersionIsLess_treatAsOutdated() {
        // given / when
        let result = self.requirement(current: "2.0.0", target: "2.1.0")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenPatchVersionIsLess_treatAsOutdated() {
        // given / when
        let result = self.requirement(current: "2.0.0", target: "2.0.1")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenCurrentIsHigher_treatAsUpToDate() {
        // given / when
        let result = self.requirement(current: "3.0.0", target: "2.0.0")

        // then
        XCTAssertNil(result)
    }

    func test_whenCurrentEqualsTarget_treatAsUpToDate() {
        // given / when
        let result = self.requirement(current: "2.0.0", target: "2.0.0")

        // then
        XCTAssertNil(result)
    }
}


// MARK: - 컴포넌트 개수가 다른 경우 zero-padding

extension AppUpdateRequirementTests {

    func test_whenCurrentHasFewerComponents_padWithZeroAndOutdated() {
        // given — "2.0"은 "2.0.0"으로 패딩되어 "2.0.1"보다 낮음
        // when
        let result = self.requirement(current: "2.0", target: "2.0.1")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenTargetHasFewerComponents_padWithZeroAndOutdated() {
        // given — target "2.0"은 "2.0.0"으로 패딩되고, current "1.9.9"는 그보다 낮음
        // when
        let result = self.requirement(current: "1.9.9", target: "2.0")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenTargetHasFewerComponents_currentIsHigher_treatAsUpToDate() {
        // given — current "2.0.1"은 target "2.0"(="2.0.0")보다 높음
        // when
        let result = self.requirement(current: "2.0.1", target: "2.0")

        // then
        XCTAssertNil(result)
    }

    func test_whenPaddedValuesAreEqual_treatAsUpToDate() {
        // given — "2.0.0" vs "2.0" → 둘 다 "2.0.0"으로 정렬되어 동일
        // when
        let result = self.requirement(current: "2.0.0", target: "2.0")

        // then
        XCTAssertNil(result)
    }

    func test_whenSingleComponent_padBothAndCompare() {
        // given — "1"은 "1.0.0"으로, "2.0.0"은 그대로 유지. 1 < 2이므로 outdated
        // when
        let result = self.requirement(current: "1", target: "2.0.0")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenSingleComponentTarget_currentIsLower_outdated() {
        // given — target "3"은 "3.0.0"으로 패딩되고, current "2.9.9"는 그보다 낮음
        // when
        let result = self.requirement(current: "2.9.9", target: "3")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenComponentCountDiffersByMoreThanOne_padWithZero() {
        // given — current "1"은 "1.0.0.0"으로 패딩되어 "1.0.0.1"보다 낮음
        // when
        let result = self.requirement(current: "1", target: "1.0.0.1")

        // then
        XCTAssertEqual(result, .forceRequired)
    }

    func test_whenShorterCurrentIsActuallyHigher_treatAsUpToDate() {
        // given — current "2.1"(="2.1.0")은 target "2.0.99"보다 높음.
        //         짧다고 무조건 낮은 게 아님을 확인.
        // when
        let result = self.requirement(current: "2.1", target: "2.0.99")

        // then
        XCTAssertNil(result)
    }
}


// MARK: - 렉시코그라피 아닌 숫자 비교

extension AppUpdateRequirementTests {

    func test_whenComponentHasTwoDigits_compareNumerically() {
        // given — "1.10.0"은 "1.9.0"보다 높은 버전.
        //         문자열 비교만 하면 "10" < "9"로 뒤집히지만 numeric 옵션으로 올바르게 비교됨.
        // when
        let result = self.requirement(current: "1.10.0", target: "1.9.0")

        // then
        XCTAssertNil(result)
    }
}


// MARK: - AppUpdateCheckUsecaseImple 테스트

class AppUpdateCheckUsecaseImpleTests: BaseTestCase, PublisherWaitable {

    var cancelBag: Set<AnyCancellable>!

    override func setUpWithError() throws {
        self.cancelBag = .init()
    }

    override func tearDownWithError() throws {
        self.cancelBag = nil
    }

    private func makeUsecase(
        currentAppVersion: String = "2.0.0",
        forceVersion: String? = nil,
        recommendVersion: String? = nil,
        shouldFail: Bool = false
    ) -> AppUpdateCheckUsecaseImple {
        let stubRepository = StubAppRepository(
            forceVersion: forceVersion,
            recommendVersion: recommendVersion,
            shouldFail: shouldFail
        )
        var stubDeviceInfo = StubDeviceInfoFetchService()
        stubDeviceInfo.stubAppVersion = currentAppVersion
        return AppUpdateCheckUsecaseImple(
            appRepository: stubRepository,
            deviceInfoFetchService: stubDeviceInfo
        )
    }
}


// MARK: - current / force / recommend 조합 결정 로직

extension AppUpdateCheckUsecaseImpleTests {

    func test_whenCurrentBelowForceVersion_emitForceRequired() {
        // given
        let expect = expectation(description: "강업 버전 미만이면 forceRequired 방출")
        let usecase = self.makeUsecase(
            currentAppVersion: "1.0.0",
            forceVersion: "2.0.0"
        )

        // when
        let requirements = self.waitOutputs(expect, for: usecase.updateRequirement) {
            usecase.checkUpdateIsNeed()
        }

        // then
        XCTAssertEqual(requirements, [.forceRequired])
    }

    func test_whenCurrentBelowRecommendVersionOnly_emitRecommended() {
        // given
        let expect = expectation(description: "권장 버전만 미만이면 recommended 방출")
        let usecase = self.makeUsecase(
            currentAppVersion: "1.0.0",
            recommendVersion: "2.0.0"
        )

        // when
        let requirements = self.waitOutputs(expect, for: usecase.updateRequirement) {
            usecase.checkUpdateIsNeed()
        }

        // then
        XCTAssertEqual(requirements, [.recommended])
    }

    func test_whenBothForceAndRecommendApply_forceTakesPriority() {
        // given — current가 force·recommend 둘 다에 걸려도 force가 우선
        let expect = expectation(description: "강업·권장 모두 해당하면 force 우선")
        let usecase = self.makeUsecase(
            currentAppVersion: "1.0.0",
            forceVersion: "2.0.0",
            recommendVersion: "1.5.0"
        )

        // when
        let requirements = self.waitOutputs(expect, for: usecase.updateRequirement) {
            usecase.checkUpdateIsNeed()
        }

        // then
        XCTAssertEqual(requirements, [.forceRequired])
    }

    func test_whenForceNotMetButRecommendMet_emitRecommended() {
        // given — current가 force는 넘었지만 recommend에는 걸리는 경우
        let expect = expectation(description: "강업 미충족·권장 충족 시 recommended")
        let usecase = self.makeUsecase(
            currentAppVersion: "2.5.0",
            forceVersion: "2.0.0",
            recommendVersion: "3.0.0"
        )

        // when
        let requirements = self.waitOutputs(expect, for: usecase.updateRequirement) {
            usecase.checkUpdateIsNeed()
        }

        // then
        XCTAssertEqual(requirements, [.recommended])
    }

    func test_whenCurrentAboveBoth_emitNothing() {
        // given
        let expect = expectation(description: "강업·권장 모두 넘으면 방출 없음")
        expect.isInverted = true
        let usecase = self.makeUsecase(
            currentAppVersion: "3.0.0",
            forceVersion: "2.0.0",
            recommendVersion: "2.5.0"
        )

        // when
        let requirements = self.waitOutputs(expect, for: usecase.updateRequirement, timeout: 0.5) {
            usecase.checkUpdateIsNeed()
        }

        // then
        XCTAssertTrue(requirements.isEmpty)
    }

    func test_whenForceAndRecommendBothMissing_emitNothing() {
        // given — 서버 응답에 버전 정보가 하나도 없는 경우
        let expect = expectation(description: "강업·권장 버전 모두 nil이면 방출 없음")
        expect.isInverted = true
        let usecase = self.makeUsecase(
            currentAppVersion: "2.0.0"
        )

        // when
        let requirements = self.waitOutputs(expect, for: usecase.updateRequirement, timeout: 0.5) {
            usecase.checkUpdateIsNeed()
        }

        // then
        XCTAssertTrue(requirements.isEmpty)
    }
}


// MARK: - 조회 실패 대응

extension AppUpdateCheckUsecaseImpleTests {

    func test_whenFetchFails_emitNothing() {
        // given
        let expect = expectation(description: "조회 실패 시 방출 없음")
        expect.isInverted = true
        let usecase = self.makeUsecase(shouldFail: true)

        // when
        let requirements = self.waitOutputs(expect, for: usecase.updateRequirement, timeout: 0.5) {
            usecase.checkUpdateIsNeed()
        }

        // then
        XCTAssertTrue(requirements.isEmpty)
    }
}


// MARK: - Stubs

private class StubAppRepository: AppRepository, @unchecked Sendable {

    private let forceVersion: String?
    private let recommendVersion: String?
    private let shouldFail: Bool

    init(
        forceVersion: String? = nil,
        recommendVersion: String? = nil,
        shouldFail: Bool = false
    ) {
        self.forceVersion = forceVersion
        self.recommendVersion = recommendVersion
        self.shouldFail = shouldFail
    }

    func loadUpdateInfo() async throws -> AppUpdateInfo {
        if shouldFail { throw RuntimeError("load failed") }
        var info = AppUpdateInfo()
        info.forceUpdateVersion = self.forceVersion
        info.recommendUpdateVersion = self.recommendVersion
        return info
    }
}
